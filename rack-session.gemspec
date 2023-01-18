# frozen_string_literal: true

require_relative "lib/rack/session/version"

Gem::Specification.new do |spec|
  spec.name = "rack-session"
  spec.version = Rack::Session::VERSION

  spec.summary = "A session implementation for Rack."
  spec.authors = ["Samuel Williams", "Jeremy Evans", "Jon Dufresne", "Philip Arndt"]
  spec.license = "MIT"

  spec.homepage = "https://github.com/rack/rack-session"

  spec.files = Dir['{lib}/**/*', '*.md']

  spec.required_ruby_version = ">= 2.4.0"

  spec.add_dependency "rack", ">= 3.0.0.beta1"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-global_expectations"
  spec.add_development_dependency "minitest-sprint"
  spec.add_development_dependency "rake"
end
