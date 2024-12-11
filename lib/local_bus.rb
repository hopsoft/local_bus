# frozen_string_literal: true

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

  # Default Bus instance
  # @rbs return: Bus
  attr_reader :bus

  # Default Station instance
  # @rbs return: Station
  attr_reader :station

  class << self
    # Publishes a message via the default Station
    #
    # @rbs topic: String | Symbol -- topic name
    # @rbs priority: Integer -- priority of the message, higher number == higher priority (default: 1)
    # @rbs timeout: Float -- seconds to wait before cancelling
    # @rbs payload: Hash[Symbol, untyped] -- message payload
    # @rbs return: Message
    def publish(...)
      instance.station.publish(...)
    end

    # Publishes a pre-built message via the default Station
    # @rbs message: Message -- message to publish
    # @rbs return: Message
    def publish_message(...)
      instance.station.publish_message(...)
    end

    # Subscribe to a topic via the default Station
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- callable that will process messages published to the topic
    # @rbs &block: (Message) -> untyped -- alternative way to provide a callable
    # @rbs return: Station
    def subscribe(...)
      instance.station.subscribe(...)
    end

    # Unsubscribes a callable from a topic via the default Station
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- subscriber that should no longer receive messages
    # @rbs return: Station
    def unsubscribe(...)
      instance.station.unsubscribe(...)
    end

    # Unsubscribes all subscribers from a topic and removes the topic via the default Station
    # @rbs topic: String -- topic name
    # @rbs return: Station
    def unsubscribe_all(...)
      instance.station.unsubscribe_all(...)
    end
  end

  private

  def initialize
    @bus = Bus.new
    @station = Station.new(bus: bus)
  end
end
