# frozen_string_literal: true

# rbs_inline: enabled

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

require "algorithms"
require "async"
require "async/barrier"
require "async/semaphore"
require "etc"
require "monitor"
require "securerandom"
require "singleton"
require "timers"

class LocalBus
  include Singleton

  attr_reader :bus
  attr_reader :station

  private

  def initialize
    @bus = Bus.new
    @station = Station.new(bus: bus)
  end
end
