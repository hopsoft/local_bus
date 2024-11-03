# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
task default: %i[]

Rake::TestTask.new :test do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run tests"
task default: :test
