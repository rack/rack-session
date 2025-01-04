# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "rack/session/encryptor"

AValidSessionCookie = Sus::Shared("a valid session cookie") do |value, cookie|
	it "can decrypt a valid session cookie" do
		expect(encryptor.decrypt(cookie)).to be == value
	rescue
		pp encryptor.encrypt(value)
	end
	
	it "can encrypt a valid session cookie" do
		encrypted = encryptor.encrypt(value)
		expect(encryptor.decrypt(encrypted)).to be == value
	end
end

describe Rack::Session::Encryptor do
	with "generic encryptor" do
		let(:secret) {"." * 64}
		let(:encryptor) {Rack::Session::Encryptor.new(secret)}
		
		# v2.0.0 (salted)
		it_behaves_like AValidSessionCookie, {}, "AbGjZyIjUxHlH1vpbU0yDc8N8MB0SV723Fj2uGYWrXxHuh99KpUiavHdw2gG1IW7e2OISpZetJzALqc_LxtVigllj9HZ7mzF1KvHPabLvfJcJ0gB_MqHGTKUMPlsSs9L9frJJuazsd1aW-7C33LB6Eg="
		it_behaves_like AValidSessionCookie, {"a" => 10}, "AbxvYQw-Fz0HW2g6uo3uSVheVv1-QaWGtg2LSVsTYq1Sds8xNLjGDCKvwACHJN1tiBA_jOoiP64kmjZRGnTBl0pv9SqsKwaRBKnY1Q5Rkc621pVlRlr98ehyYhfJT_svoUJXCYfrWgoGO_n8zj4Cgi4="
		it_behaves_like AValidSessionCookie, {"a" => 10, "b" => 20}, "ATfvdnPvcdW4ohIm7MnIdBLKwvqK4j58Rt9hQZhkifZq9IW15sDUViOMM0ClaLONci1fChW0pTuLmFxK3tQ0ch7GxiTVNqfNI1GFlC2epQr-bkuWNF0AbpC4FzBhn94RVQ1MLdd1pPaFQF6E40VvUjw="
		it_behaves_like AValidSessionCookie, {a: 10, b: 20}, "AV6-1fg2bphnDYJvj4B34LiDed0QLzBsxboLVerKCk2Nv9_HBaOeTOCJMrkW946IHS3HxXJ10hFrXTlHTJLn9m96SRlGODJjGTu1ltTcFpiQo-dikKvCDmuIP-4t0cxEVl2pYfgO3wexd9MrJzOKuzQ="
	end
end
