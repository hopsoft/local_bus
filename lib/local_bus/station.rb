# frozen_string_literal: true

# rbs_inline: enabled
# rubocop:disable Lint/MissingCopEnableDirective
# rubocop:disable Style/ArgumentsForwarding

class LocalBus
  # An in-process message queuing system that buffers messages before publishing them via Bus.
  #
  # NOTE: Station shares the same publishing interface as Bus
  # IMPORTANT: Be sure to release resources like database connections in subscribers when publishing via Station.
  #
  class Station
    include MonitorMixin

    class QueueFullError < StandardError; end

    # Constructor
    #
    # @note Delays process exit in an attempt to flush the queue to avoid dropping messages.
    #       Exit flushing makes a "best effort" to process all messages, but it's not guaranteed.
    #       Will not delay process exit when the queue is empty.
    #
    # @rbs bus: Bus -- local message bus (default: Bus.new)
    # @rbs interval: Float -- queue polling interval in seconds (default: 0.01)
    # @rbs size: Integer -- max queue size (default: 10_000)
    # @rbs threads: Integer -- number of threads to use (default: Etc.nprocessors)
    # @rbs timeout: Float -- seconds to wait for subscribers to process the message before cancelling (default: 60)
    # @rbs flush_delay: Float -- seconds to wait for the queue to flush at process exit (default: 1)
    # @rbs return: void
    def initialize(bus: Bus.new, interval: 0.01, size: 10_000, threads: Etc.nprocessors, timeout: 60, flush_delay: 1)
      super()
      @bus = bus
      @interval = [interval.to_f, 0.01].max
      @size = size.to_i.positive? ? size.to_i : 10_000
      @threads = [threads.to_i, 1].max
      @timeout = timeout.to_f
      @queue = Containers::PriorityQueue.new
      at_exit { stop timeout: [flush_delay.to_f, 1].max }
      start
    end

    # Bus instance
    # @rbs return: Bus
    attr_reader :bus

    # Queue polling interval in seconds
    # @rbs return: Float
    attr_reader :interval

    # Max queue size
    # @rbs return: Integer
    attr_reader :size

    # Number of threads to use
    # @rbs return: Integer
    attr_reader :threads

    # Default timeout for message processing (in seconds)
    # @rbs return: Float
    attr_reader :timeout

    # Starts the station
    # @rbs interval: Float -- queue polling interval in seconds (default: 0.01)
    # @rbs threads: Integer -- number of threads to use (default: self.threads)
    # @rbs return: void
    def start(interval: self.interval, threads: self.threads)
      interval = [interval.to_f, 0.01].max
      threads = [threads.to_i, 1].max

      synchronize do
        return if running? || stopping?

        timers = Timers::Group.new
        @pool = []
        threads.times do
          @pool << Thread.new do
            Thread.current.report_on_exception = true
            timers.every interval do
              message = synchronize { @queue.pop unless @queue.empty? || stopping? }
              bus.send :publish_message, message if message
            end

            loop do
              timers.wait
              break if stopping?
            end
          ensure
            timers.cancel
          end
        end
      end
    end

    # Stops the station
    # @rbs timeout: Float -- seconds to wait for message processing before killing the thread pool (default: nil)
    # @rbs return: void
    def stop(timeout: nil)
      synchronize do
        return unless running?
        return if stopping?
        @stopping = true
      end

      @pool&.each do |thread|
        timeout.is_a?(Numeric) ? thread.join(timeout) : thread.join
      end
    ensure
      @stopping = false
      @pool = nil
    end

    def stopping?
      synchronize { !!@stopping }
    end

    # Indicates if the station is running
    # @rbs return: bool
    def running?
      synchronize { !!@pool }
    end

    # The number of pending unprocessed messages
    # @rbs return: Integer
    def pending
      synchronize { @queue.size }
    end

    # Subscribe to a topic
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- callable that will process messages published to the topic
    # @rbs &block: (Message) -> untyped -- alternative way to provide a callable
    # @rbs return: self
    def subscribe(topic, callable: nil, &block)
      bus.subscribe(topic, callable: callable || block)
      self
    end

    # Unsubscribe from a topic
    # @rbs topic: String -- topic name
    # @rbs return: self
    def unsubscribe(topic)
      bus.unsubscribe(topic)
      self
    end

    # Unsubscribes all subscribers from a topic and removes the topic
    # @rbs topic: String -- topic name
    # @rbs return: self
    def unsubscribe_all(topic)
      bus.unsubscribe_all topic
      self
    end

    # Publishes a message to the queue
    #
    # @rbs topic: String | Symbol -- topic name
    # @rbs priority: Integer -- priority of the message, higher number == higher priority (default: 1)
    # @rbs timeout: Float -- seconds to wait before cancelling
    # @rbs payload: Hash[Symbol, untyped] -- message payload
    # @rbs return: Message
    def publish(topic, priority: 1, timeout: self.timeout, **payload)
      publish_message Message.new(topic, timeout: timeout, **payload), priority: priority
    end

    # Publishes a message to the queue
    # @rbs message: Message -- message to publish
    # @rbs return: Message
    def publish_message(message, priority: 1)
      synchronize do
        raise QueueFullError, "Queue is at capacity! #{size}" if @queue.size >= size
        @queue.push message, priority
      end
    end
  end
end
