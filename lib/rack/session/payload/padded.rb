# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "wrapper"

module Rack
  module Session
    module Payload
      class Padded < Wrapper
        MAXIMUM_SIZE = 4096
        
        def initialize(delegate, size)
          super(delegate)

          if size < 2 or size > MAXIMUM_SIZE
            raise ArgumentError, "Size must be between 2 and #{MAXIMUM_SIZE}!"
          end

          @size = size
        end

        # 2-byte padding size:
        FORMAT = "v"

        # @returns [String] The serialized value, with padding. The first 2 bytes of the data indicate the amount of padding.
        def dump(...)
          data = super(...)

          # 2 bytes for padding size, appended to the start of the data:
          padding_size = @size - (data.bytesize + 2) % @size
          padding_bytes = SecureRandom.random_bytes(padding_size)

          return [padding_size].pack(FORMAT) + padding_bytes + data
        end

        # @returns [Object] The deserialized value, with padding removed.
        def load(data)
          padding_size, _ = data.unpack(FORMAT)

          data = data.slice(padding_size+2, data.bytesize)

          return super(data)
        end
      end
    end
  end
end
