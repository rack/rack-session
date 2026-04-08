# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "wrapper"

require "zlib"

module Rack
  module Session
    module Payload
			class Compressed
				def initialize(delegate)
					@delegate = delegate
				end

				def load(data)
					@delegate.load(Zlib.inflate(data))
				end

				def dump(value)
					Zlib.deflate(@delegate.dump(value))
				end
			end
		end
	end
end
