# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "minitest/autorun"
require "rack/session/encryptor"

describe Rack::Session do
  describe "with an encryptor" do
    let(:secret) { "." * 64 }
    let(:encryptor) { Rack::Session::Encryptor.new(secret) }

    def self.test_session_cookie(value, cookie)
      it "decrypts the cookie to produce #{value.inspect}" do
        _(encryptor.decrypt(cookie)).must_equal value
      rescue => error
        warn "Decryption failed for: #{value.inspect}"
        pp encryptor.encrypt(value)
        raise error
      end

      it "encrypts and decrypts #{value.inspect} round-trip" do
        encrypted = encryptor.encrypt(value)
        _(encryptor.decrypt(encrypted)).must_equal value
      end
    end

    test_session_cookie({}, "AbGjZyIjUxHlH1vpbU0yDc8N8MB0SV723Fj2uGYWrXxHuh99KpUiavHdw2gG1IW7e2OISpZetJzALqc_LxtVigllj9HZ7mzF1KvHPabLvfJcJ0gB_MqHGTKUMPlsSs9L9frJJuazsd1aW-7C33LB6Eg=")
    test_session_cookie({"a" => 10}, "AbxvYQw-Fz0HW2g6uo3uSVheVv1-QaWGtg2LSVsTYq1Sds8xNLjGDCKvwACHJN1tiBA_jOoiP64kmjZRGnTBl0pv9SqsKwaRBKnY1Q5Rkc621pVlRlr98ehyYhfJT_svoUJXCYfrWgoGO_n8zj4Cgi4=")
    test_session_cookie({"a" => 10, "b" => 20}, "ATfvdnPvcdW4ohIm7MnIdBLKwvqK4j58Rt9hQZhkifZq9IW15sDUViOMM0ClaLONci1fChW0pTuLmFxK3tQ0ch7GxiTVNqfNI1GFlC2epQr-bkuWNF0AbpC4FzBhn94RVQ1MLdd1pPaFQF6E40VvUjw=")
    test_session_cookie({a: 10, b: 20}, "AV6-1fg2bphnDYJvj4B34LiDed0QLzBsxboLVerKCk2Nv9_HBaOeTOCJMrkW946IHS3HxXJ10hFrXTlHTJLn9m96SRlGODJjGTu1ltTcFpiQo-dikKvCDmuIP-4t0cxEVl2pYfgO3wexd9MrJzOKuzQ=")
  end
end
