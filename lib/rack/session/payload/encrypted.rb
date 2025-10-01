require_relative "encrypted_v1"
require_relative "encrypted_v2"

module Rack
  module Session
    module Payload
      class Encrypted < Wrapper
        def initialize(delegate, secret, **options)
          @versioned = {
            "\1" => EncryptedV1.new(delegate, secret, **options),
            "\2" => EncryptedV2.new(delegate, secret, **options)
          }
          
          @default = @versioned["\2"]
        end
        
        def dump(value)
          @default.dump(value)
        end
        
        def load(data)
          version_data = data.slice(0, 4)
          
          # Transform the 4 bytes into non-URL-safe base64-encoded data. Nothing
          # happens if the data is already non-URL-safe base64.
          version_data.tr!('-_', '+/')
          version = Base64.strict_decode64(version_data)

          @versioned.fetch(version, @default).load(data)
        end
      end
    end
  end
end
