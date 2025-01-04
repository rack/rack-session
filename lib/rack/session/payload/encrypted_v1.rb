# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "wrapper"
require_relative "../error"

require "rack/utils"

module Rack
  module Session
    module Payload
      # Uses `AES-256-CTR` for encryption, combined with `HMAC` (Hash-based Message Authentication Code) for data *integrity/authentication*. The encryption and integrity mechanisms are separate, requiring both components to work together correctly.
      #
      # This is considered a legacy encryption scheme and should not be used for new applications. It is recommended to use `EncryptedV2` instead (the default for new sessions).
      class EncryptedV1 < Wrapper
        # The secret String must be at least 64 bytes in size. The first 32 bytes
        # will be used for the encryption cipher key. The remainder will be used
        # for an HMAC key.
        #
        # Options may include:
        # * :serialize_json
        #     Use JSON for message serialization instead of Marshal. This can be
        #     viewed as a security enhancement.
        # * :pad_size
        #     Pad encrypted message data, to a multiple of this many bytes
        #     (default: 32). This can be between 2-4096 bytes, or +nil+ to disable
        #     padding.
        # * :purpose
        #     Limit messages to a specific purpose. This can be viewed as a
        #     security enhancement to prevent message reuse from different contexts
        #     if keys are reused.
        #
        # Cryptography and Output Format:
        #
        #   urlsafe_encode64(version + random_data + IV + encrypted data + HMAC)
        #
        #  Where:
        #  * version - 1 byte with value 0x01
        #  * random_data - 32 bytes used for generating the per-message secret
        #  * IV - 16 bytes random initialization vector
        #  * HMAC - 32 bytes HMAC-SHA-256 of all preceding data, plus the purpose
        #    value
        def initialize(delegate, secret, purpose: nil, **options)
          super(delegate)

          raise ArgumentError, 'secret must be a String' unless secret.is_a?(String)
          raise ArgumentError, "invalid secret: #{secret.bytesize}, must be >=64" unless secret.bytesize >= 64

          @purpose = purpose

          @hmac_secret = secret.dup.force_encoding(Encoding::BINARY)
          @cipher_secret = @hmac_secret.slice!(0, 32)

          @hmac_secret.freeze
          @cipher_secret.freeze
        end

        def load(data)
          super(decrypt(data))
        end

        def dump(value)
          encrypt(super(value))
        end

        private

        def decrypt(data)
          signature = data.slice!(-32..-1)
          verify_authenticity!(data, signature)

          version = data.slice!(0, 1)
          raise InvalidMessage, 'wrong version' unless version == "\1"

          message_secret = data.slice!(0, 32)
          cipher_iv = data.slice!(0, 16)

          cipher = new_cipher
          cipher.decrypt

          set_cipher_key(cipher, cipher_secret_from_message_secret(message_secret))

          cipher.iv = cipher_iv
          data = cipher.update(data) << cipher.final

          deserialized_message data
        rescue ArgumentError
          raise InvalidSignature, 'Message invalid'
        end

        def encrypt(data)
          version = "\1"

          serialized_payload = serialize_payload(message)
          message_secret, cipher_secret = new_message_and_cipher_secret

          cipher = new_cipher
          cipher.encrypt

          set_cipher_key(cipher, cipher_secret)

          cipher_iv = cipher.random_iv

          encrypted_data = cipher.update(serialized_payload) << cipher.final

          data = String.new
          data << version
          data << message_secret
          data << cipher_iv
          data << encrypted_data
          data << compute_signature(data)
        end

        def new_cipher
          OpenSSL::Cipher.new('aes-256-ctr')
        end

        def new_message_and_cipher_secret
          message_secret = SecureRandom.random_bytes(32)

          [message_secret, cipher_secret_from_message_secret(message_secret)]
        end

        def cipher_secret_from_message_secret(message_secret)
          OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), @cipher_secret, message_secret)
        end

        def set_cipher_key(cipher, key)
          cipher.key = key
        end

        def compute_signature(data)
          signing_data = data
          signing_data += @options[:purpose] if @options[:purpose]

          OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), @hmac_secret, signing_data)
        end

        def verify_authenticity!(data, signature)
          raise InvalidMessage, 'Message is invalid' if data.nil? || signature.nil?

          unless Rack::Utils.secure_compare(signature, compute_signature(data))
            raise InvalidSignature, 'HMAC is invalid'
          end
        end
      end
    end
  end
end
