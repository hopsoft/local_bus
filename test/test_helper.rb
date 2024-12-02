# frozen_string_literal: true

$VERBOSE = nil # silence warnings as several are emitted by gem dependencies

require "amazing_print"
require "bundler/setup"
require "minitest/autorun"
require "minitest/reporters"
require "pry-byebug"
require "pry-doc"
require "local_bus"

AmazingPrint.pry!
FileUtils.mkdir_p "tmp"

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: true, fail_fast: true, location: true),
  Minitest::Reporters::MeanTimeReporter.new(show_count: 5, show_progress: false, sort_column: :avg, previous_runs_filename: "tmp/minitest-report")
]
