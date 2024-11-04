# frozen_string_literal: true

require_relative "lib/local_bus/version"

Gem::Specification.new do |s|
  s.name = "local_bus"
  s.version = LocalBus::VERSION
  s.authors = ["Nate Hopkins (hopsoft)"]
  s.email = ["natehop@gmail.com"]
  s.homepage = "https://github.com/hopsoft/local_bus"
  s.summary = "A high-performance, thread-safe pub/sub system for Ruby applications with async I/O and background processing support"
  s.description = "LocalBus provides a robust publish/subscribe system for Ruby applications that enables decoupled intra-process communication. It features both immediate (async I/O) and background (thread pool) processing modes, comprehensive error handling, and configurable concurrency controls - all designed to help organize event-driven behavior within a single process."
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
  s.add_development_dependency "tocer"
  s.add_development_dependency "yard"
end
