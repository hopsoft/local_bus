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
  Minitest::Reporters::DefaultReporter.new(color: true, fail_fast: true, location: true)

  # the test suite has intentional latency... benchmarking speed doesn't make much sense
  # Minitest::Reporters::MeanTimeReporter.new(show_count: 5, show_progress: false, sort_column: :avg, previous_runs_filename: "tmp/minitest-report")
]

RUNNING_IN_CI = ENV["CI"] == "true"
DEFAULT_LATENCY = RUNNING_IN_CI ? 1.0 : 0.25
DEFAULT_TIMEOUT_MULTIPLIER = RUNNING_IN_CI ? 3 : 1.25
