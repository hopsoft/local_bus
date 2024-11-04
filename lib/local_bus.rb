# frozen_string_literal: true

# rbs_inline: enabled

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

require "async"
require "async/barrier"
require "async/semaphore"
require "concurrent-ruby"
require "monitor"
require "securerandom"
require "singleton"

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
