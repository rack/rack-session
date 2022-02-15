# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

desc "Run all the tests"
task default: :test

Rake::TestTask.new("test:regular") do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/spec_*.rb"]
  t.warning = false
  t.verbose = true
end

desc "Run tests with coverage"
task "test_cov" do
  ENV['COVERAGE'] = '1'
  Rake::Task['test:regular'].invoke
end

desc "Run separate tests for each test file, to test directly requiring components"
task "test:separate" do
  fails = []
  FileList["test/**/spec_*.rb"].each do |file|
    puts "#{FileUtils::RUBY} -w #{file}"
    fails << file unless system({'SEPARATE'=>'1'},  FileUtils::RUBY, '-w', file)
  end
  if fails.empty?
    puts 'All test files passed'
  else
    puts "Failures in the following test files:"
    puts fails
    raise "At least one separate test failed"
  end
end

desc "Run all the fast + platform agnostic tests"
task test: %w[test:regular test:separate]

desc "Run all the tests we run on CI"
task ci: :test

task doc: :rdoc

# def clone_and_test(url, name, command)
#   path = "external/#{name}"
#   FileUtils.rm_rf path
#   FileUtils.mkdir_p path
# 
#   sh("git clone #{url} #{path}")
# 
#   # I tried using `bundle config --local local.async ../` but it simply doesn't work.
#   File.open("#{path}/Gemfile", "a") do |file|
#     file.puts("gem 'rack', path: '../../'")
#   end
# 
#   sh("cd #{path} && bundle install && #{command}")
# end
# 
# task :external do
#   # In order not to interfere with external tests: rename our config file
#   FileUtils.mv ".rubocop.yml", ".rack.rubocop.yml.disabled"
# 
#   Bundler.with_clean_env do
#     clone_and_test("https://github.com/rack/rack-attack", "rack-attack", "bundle exec rake test")
#     clone_and_test("https://github.com/rtomayko/rack-cache", "rack-cache", "bundle exec rake")
#     clone_and_test("https://github.com/socketry/falcon", "falcon", "bundle exec rspec")
#   end
# end
