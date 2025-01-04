# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.
# Copyright, 2022, by Philip Arndt.

require_relative "payload/encrypted"
require_relative "payload/padded"

module Rack
  module Session
    class Encryptor
      def initialize(secrets, delegate: Marshal, pad_size: nil, **options)
        @delegate = Payload::Encrypted.new(delegate, secrets, **options)

        if pad_size
          @delegate = Payload::Padded.new(@delegate, pad_size)
        end
      end

      def load(data)
        @delegate.load(data)
      end

      def decrypt(data)
        self.load(data)
      end

      def dump(value)
        @delegate.dump(value)
      end

      def encrypt(value)
        self.dump(value)
      end
    end
  end
end
