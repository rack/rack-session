# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Rack
  module Session
    class Error < StandardError
    end

    class InvalidSignature < Error
    end

    class InvalidMessage < Error
    end
  end
end
