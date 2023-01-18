# frozen_string_literal: true

module Rack
  module Session
    autoload :Cookie, "rack/session/cookie"
    autoload :Pool, "rack/session/pool"
    autoload :Memcache, "rack/session/memcache"
  end
end
