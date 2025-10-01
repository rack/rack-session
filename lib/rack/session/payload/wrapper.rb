# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Rack
  module Session
    module Payload
      class Wrapper
        def initialize(delegate)
          @delegate = delegate
        end

        # Load the payload from the given value.
        #
        # @parameter value [String] The value to load the payload from, typically the session cookie.
        def load(data)
          @delegate.load(data)
        end

        # Dump the payload to a string.
        #
        # @parameter value [Object] The payload to dump.
        def dump(value, **options)
          @delegate.dump(value, **options)
        end
      end
    end
  end
end
