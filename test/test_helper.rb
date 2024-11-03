# frozen_string_literal: true

require "amazing_print"
require "bundler/setup"
require "minitest/autorun"
require "minitest/reporters"
require "pry-byebug"
require "pry-doc"
require "local_bus"

AmazingPrint.defaults = {indent: 2, index: false, ruby19_syntax: true}
AmazingPrint.pry!
FileUtils.mkdir_p "tmp"

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: true, fail_fast: true, location: true)
]
