# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require_relative 'helper'
require 'rack/session/encryptor'

require 'base64'
require 'json'
require 'securerandom'

module EncryptorTests
  def self.included(_base)
    describe 'encryptor' do
      it 'initialize does not destroy key string' do
        encryptor_class.new(@secret)

        @secret.size.must_equal 64
      end

      it 'initialize raises ArgumentError on invalid key' do
        -> { encryptor_class.new ['foo'] }.must_raise ArgumentError
      end

      it 'initialize raises ArgumentError on short key' do
        -> { encryptor_class.new 'key' }.must_raise ArgumentError
      end

      it 'decrypts an encrypted message' do
        encryptor = encryptor_class.new(@secret)

        message = encryptor.encrypt({ 'foo' => 'bar' })

        encryptor.decrypt(message).must_equal({ 'foo' => 'bar' })
      end

      it 'decrypt raises InvalidSignature for tampered messages' do
        encryptor = encryptor_class.new(@secret)

        message = encryptor.encrypt({ 'foo' => 'bar' })

        decoded_message = Base64.urlsafe_decode64(message)
        tampered_message = Base64.urlsafe_encode64(decoded_message.tap do |m|
          m[m.size - 1] = (m[m.size - 1].unpack1('C') ^ 1).chr
        end)

        lambda {
          encryptor.decrypt(tampered_message)
        }.must_raise Rack::Session::Encryptor::InvalidSignature
      end

      it 'decrypts an encrypted message with purpose' do
        encryptor = encryptor_class.new(@secret, purpose: 'testing')

        message = encryptor.encrypt({ 'foo' => 'bar' })

        encryptor.decrypt(message).must_equal({ 'foo' => 'bar' })
      end

      # The V1 encryptor defaults to the Marshal serializer, while the V2
      # encryptor always uses the JSON serializer. This means that we are
      # indirectly covering both serializers.
      it 'decrypts an encrypted message with UTF-8 data' do
        encryptor = encryptor_class.new(@secret)

        encrypted_message = encryptor.encrypt({ 'foo' => 'bar 😀' })
        decrypted_message = encryptor.decrypt(encrypted_message)

        decrypted_message.must_equal({ 'foo' => 'bar 😀' })
      end

      it 'decrypts raises InvalidSignature without purpose' do
        encryptor = encryptor_class.new(@secret, purpose: 'testing')
        other_encryptor = encryptor_class.new(@secret)

        message = other_encryptor.encrypt({ 'foo' => 'bar' })

        -> { encryptor.decrypt(message) }.must_raise Rack::Session::Encryptor::InvalidSignature
      end

      it 'decrypts raises InvalidSignature with different purpose' do
        encryptor = encryptor_class.new(@secret, purpose: 'testing')
        other_encryptor = encryptor_class.new(@secret, purpose: 'other')

        message = other_encryptor.encrypt({ 'foo' => 'bar' })

        -> { encryptor.decrypt(message) }.must_raise Rack::Session::Encryptor::InvalidSignature
      end

      it 'initialize raises ArgumentError on invalid pad_size' do
        -> { encryptor_class.new @secret, pad_size: :bar }.must_raise ArgumentError
      end

      it 'initialize raises ArgumentError on to short pad_size' do
        -> { encryptor_class.new @secret, pad_size: 1 }.must_raise ArgumentError
      end

      it 'initialize raises ArgumentError on to long pad_size' do
        -> { encryptor_class.new @secret, pad_size: 8023 }.must_raise ArgumentError
      end

      it 'decrypts an encrypted message without pad_size' do
        encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: nil)

        message = encryptor.encrypt({ 'foo' => 'bar' })

        encryptor.decrypt(message).must_equal({ 'foo' => 'bar' })
      end
    end
  end
end

describe Rack::Session::Encryptor do
  def setup
    @secret = SecureRandom.random_bytes(64)
  end

  describe 'V1' do
    def encryptor_class
      Rack::Session::Encryptor::V1
    end

    include EncryptorTests

    it 'encryptor with pad_size has message payload size to multiple of pad_size' do
      encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 24)
      message = encryptor.encrypt({ 'foo' => 'bar' * 4 })

      decoded_message = Base64.urlsafe_decode64(message)

      # slice 1 byte for version, 32 bytes for cipher_secret, 16 bytes for IV
      # from the start of the string and 32 bytes at the end of the string
      encrypted_payload = decoded_message[(1 + 32 + 16)..-33]

      (encrypted_payload.bytesize % 24).must_equal 0
    end

    it 'encryptor with pad_size increases message size' do
      no_pad_encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: nil)
      pad_encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 64)

      message_without = Base64.urlsafe_decode64(no_pad_encryptor.encrypt(''))
      message_with = Base64.urlsafe_decode64(pad_encryptor.encrypt(''))
      message_size_diff = message_with.bytesize - message_without.bytesize

      message_with.bytesize.must_be :>, message_without.bytesize
      message_size_diff.must_equal 64 - Marshal.dump('').bytesize - 2
    end

    # This test checks the one-time message key IS NOT used as the cipher key.
    # Doing so would remove the confidentiality assurances as the key is
    # essentially included in plaintext then.
    it 'uses a secret cipher key for encryption and decryption' do
      cipher = OpenSSL::Cipher.new('aes-256-ctr')
      encryptor = encryptor_class.new(@secret)

      message = encryptor.encrypt({ 'foo' => 'bar' })
      raw_message = Base64.urlsafe_decode64(message)

      _ver = raw_message.slice!(0, 1)
      key = raw_message.slice!(0, 32)
      iv = raw_message.slice!(0, 16)

      cipher.decrypt
      cipher.key = key
      cipher.iv = iv

      data = cipher.update(raw_message) << cipher.final

      # "data" should now be random bytes because we tried to decrypt a message
      # with the wrong key

      padding_bytes, = data.unpack('v') # likely a large number
      serialized_data = data.slice(2 + padding_bytes, data.bytesize) # likely nil

      -> { Marshal.load serialized_data }.must_raise TypeError
    end

    it 'it calls set_cipher_key with the correct key' do
      encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 24)
      message = encryptor.encrypt({ 'foo' => 'bar' })

      message_key = Base64.urlsafe_decode64(message).slice(1, 32)

      callable = proc do |cipher, key|
        key.wont_equal @secret
        key.wont_equal message_key

        cipher.key = key
      end

      encryptor.stub :set_cipher_key, callable do
        encryptor.decrypt message
      end
    end
  end

  describe 'V2' do
    def encryptor_class
      Rack::Session::Encryptor::V2
    end

    include EncryptorTests

    it 'encryptor with pad_size has message payload size to multiple of pad_size' do
      encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 24)
      message = encryptor.encrypt({ 'foo' => 'bar' * 4 })

      decoded_message = Base64.strict_decode64(message)

      # slice 1 byte for version, 32 bytes for cipher_secret, 12 bytes for IV,
      # 16 bytes for the auth tag from the start of the string
      encrypted_payload = decoded_message[(1 + 32 + 12 + 16)..decoded_message.size]

      (encrypted_payload.bytesize % 24).must_equal 0
    end

    it 'encryptor with pad_size increases message size' do
      no_pad_encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: nil)
      pad_encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 64)

      message_without = Base64.strict_decode64(no_pad_encryptor.encrypt(''))
      message_with = Base64.strict_decode64(pad_encryptor.encrypt(''))
      message_size_diff = message_with.bytesize - message_without.bytesize

      message_with.bytesize.must_be :>, message_without.bytesize
      message_size_diff.must_equal 64 - JSON.dump('').bytesize - 2
    end

    it 'raises InvalidMessage on version mismatch' do
      encryptor = encryptor_class.new(@secret, purpose: 'testing')
      message = encryptor.encrypt({ 'foo' => 'bar' })

      decoded_message = Base64.strict_decode64(message)
      decoded_message[0] = "\1"
      reencoded_message = Base64.strict_encode64(decoded_message)

      -> { encryptor.decrypt(reencoded_message) }.must_raise Rack::Session::Encryptor::InvalidMessage
    end

    # This test checks the one-time message key IS NOT used as the cipher key.
    # Doing so would remove the confidentiality assurances as the key is
    # essentially included in plaintext then.
    it 'uses a secret cipher key for encryption and decryption' do
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      encryptor = encryptor_class.new(@secret)

      message = encryptor.encrypt({ 'foo' => 'bar' })
      raw_message = Base64.strict_decode64(message)

      version = raw_message.slice!(0, 1)
      salt = raw_message.slice!(0, 32)
      iv = raw_message.slice!(0, 12)
      auth_tag = raw_message.slice!(0, 16)

      cipher.decrypt
      cipher.key = salt
      cipher.iv = iv
      cipher.auth_tag = auth_tag
      cipher.auth_data = version + salt

      -> { cipher.update(raw_message) << cipher.final }.must_raise OpenSSL::Cipher::CipherError
    end

    it 'it calls set_cipher_key with the correct key' do
      encryptor = encryptor_class.new(@secret, purpose: 'testing', pad_size: 24)
      message = encryptor.encrypt({ 'foo' => 'bar' })

      message_key = Base64.strict_decode64(message).slice(1, 32)

      callable = proc do |cipher, key|
        key.wont_equal @secret
        key.wont_equal message_key

        cipher.key = key
      end

      encryptor.stub :set_cipher_key, callable do
        encryptor.decrypt message
      end
    end

    it 'ignores serialize_json' do
      encryptor_no_json = encryptor_class.new(@secret, purpose: 'testing', serialize_json: false)
      encryptor = encryptor_class.new(@secret, purpose: 'testing', serialize_json: true)

      message = encryptor_no_json.encrypt({ 'foo' => 'bar' })

      encryptor.decrypt(message).must_equal({ 'foo' => 'bar' })
    end
  end

  describe '#encrypt' do
    it 'encrypts the message with encrytor v1 when initialitialized with mode v1' do
      encryptor = Rack::Session::Encryptor.new(@secret, { mode: :v1 })

      encrypted_message = encryptor.encrypt({ 'foo' => 'bar' })
      version = Base64.urlsafe_decode64(encrypted_message)[0]

      version.must_equal "\1"
    end

    it 'encrypts the message with encrytor v1 when initialitialized with a mode other than v1' do
      encryptor = Rack::Session::Encryptor.new(@secret, { mode: :not_v1 })

      encrypted_message = encryptor.encrypt({ 'foo' => 'bar' })
      version = Base64.strict_decode64(encrypted_message)[0]

      version.must_equal "\2"
    end
  end

  describe '#decrypt' do
    it 'decrypts the message with encryptor v1 when initialized with mode v1' do
      encryptor = Rack::Session::Encryptor.new(@secret, { mode: :v1 })

      encrypted_message = encryptor.encrypt({ 'foo' => 'bar' })
      decrypted_message = encryptor.decrypt(encrypted_message)

      decrypted_message.must_equal({ 'foo' => 'bar' })
    end

    it 'decrypts the message with encryptor v2 when initialized with mode v2' do
      encryptor = Rack::Session::Encryptor.new(@secret, { mode: :v2 })

      encrypted_message = encryptor.encrypt({ 'foo' => 'bar' })
      decrypted_message = encryptor.decrypt(encrypted_message)

      decrypted_message.must_equal({ 'foo' => 'bar' })
    end

    it 'decrypts the message by trying to guess the encryptor when initialized without a mode' do
      encryptor_without_mode = Rack::Session::Encryptor.new(@secret)
      encryptor_mode_v1 = Rack::Session::Encryptor.new(@secret, { mode: :v1 })
      encryptor_mode_v2 = Rack::Session::Encryptor.new(@secret, { mode: :v2 })

      encrypted_message_v1 = encryptor_mode_v1.encrypt({ 'foo' => 'bar' })
      encrypted_message_v2 = encryptor_mode_v2.encrypt({ 'foo' => 'bar' })

      decrypted_message_v1 = encryptor_without_mode.decrypt(encrypted_message_v1)
      decrypted_message_v2 = encryptor_without_mode.decrypt(encrypted_message_v2)

      decrypted_message_v1.must_equal({ 'foo' => 'bar' })
      decrypted_message_v2.must_equal({ 'foo' => 'bar' })
    end
  end
end
