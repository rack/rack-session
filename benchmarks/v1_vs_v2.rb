#!/usr/bin/env ruby

require 'benchmark/ips'
require 'securerandom'

require_relative '../lib/rack/session'
require_relative '../lib/rack/session/encryptor'

DATA = SecureRandom.alphanumeric(4 * 2**10).slice!(0, 4096)

SECRET = SecureRandom.random_bytes(64)
CONFIG = {}

ENCRYPTOR_V1 = Rack::Session::Encryptor::V1.new(SECRET, CONFIG)
ENCRYPTOR_V2 = Rack::Session::Encryptor::V2.new(SECRET, CONFIG)

Benchmark.ips do |x|
  x.report('v1 encrypt') do
    ENCRYPTOR_V1.encrypt(DATA)
  end

  x.report('v2 encrypt') do
    ENCRYPTOR_V2.encrypt(DATA)
  end

  x.compare!
end

ENCRYPTED_DATA_V1 = ENCRYPTOR_V1.encrypt(DATA)
ENCRYPTED_DATA_V2 = ENCRYPTOR_V2.encrypt(DATA)

Benchmark.ips do |x|
  x.report('v1 decrypt') do
    ENCRYPTOR_V1.decrypt(ENCRYPTED_DATA_V1)
  end

  x.report('v2 decrypt') do
    ENCRYPTOR_V2.decrypt(ENCRYPTED_DATA_V2)
  end

  x.compare!
end

TARGET = -1
ENCRYPTED_DATA_V1[TARGET] = "\0"
ENCRYPTED_DATA_V2[TARGET] = "\0"

Benchmark.ips do |x|
  x.report('v1 decrypt tampered') do
    ENCRYPTOR_V1.decrypt(ENCRYPTED_DATA_V1)
  rescue Rack::Session::Encryptor::Error
    nil
  else
    raise "Shouldn't be here!"
  end

  x.report('v2 decrypt tampered') do
    ENCRYPTOR_V2.decrypt(ENCRYPTED_DATA_V2)
  rescue Rack::Session::Encryptor::Error
    nil
  else
    raise "Shouldn't be here!"
  end

  x.compare!
end
