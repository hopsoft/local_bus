# frozen_string_literal: true

require_relative "lib/local_bus/version"

Gem::Specification.new do |s|
  s.name = "local_bus"
  s.version = LocalBus::VERSION
  s.authors = ["Nate Hopkins (hopsoft)"]
  s.email = ["natehop@gmail.com"]
  s.homepage = "https://github.com/hopsoft/local_bus"
  s.summary = "A thread-safe pub/sub system for decoupled intra-process communication"
  s.description = s.summary
  s.license = "MIT"

  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = s.homepage
  s.metadata["changelog_uri"] = s.homepage + "/blob/main/CHANGELOG.md"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "README.md"]

  s.required_ruby_version = ">= 3.0"

  s.add_dependency "async"
  s.add_dependency "concurrent-ruby"
  s.add_dependency "zeitwerk"

  s.add_development_dependency "amazing_print"
  s.add_development_dependency "fiddle"
  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-reporters"
  s.add_development_dependency "ostruct"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "pry-doc"
  s.add_development_dependency "rake"
  s.add_development_dependency "rbs-inline"
  s.add_development_dependency "standard"
  s.add_development_dependency "yard"
end
