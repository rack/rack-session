# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

if ENV.delete('COVERAGE')
  require 'coverage'
  require 'simplecov'

  def SimpleCov.rack_coverage(**_opts)
    start do
      add_filter '/test/'
      add_group('Missing') { |src| src.covered_percent < 100 }
      add_group('Covered') { |src| src.covered_percent == 100 }
    end
  end
  SimpleCov.rack_coverage
end

$:.unshift(File.expand_path('../lib', __dir__))
if ENV['SEPARATE']
  def self.separate_testing
    yield
  end
else
  require_relative '../lib/rack/session'

  def self.separate_testing; end
end
require 'minitest/global_expectations/autorun'
require 'stringio'
require 'debug'
