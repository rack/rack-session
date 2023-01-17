# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
  gem "bake"
  gem "bake-gem"

  gem "rubocop", require: false
  gem "rubocop-packaging", require: false
end

group :doc do
  gem 'rdoc'
end

group :test do
  gem "bake-test-external"
end
