# frozen_string_literal: true

class LocalBus
  # The Station serves as a queuing system for messages, similar to a bus station where passengers wait for their bus.
  #
  # When a message is published to the Station, it is queued and processed at a later time, allowing for deferred execution.
  # This is particularly useful for tasks that can be handled later.
  #
  # The Station employs a thread pool to manage message processing, enabling high concurrency and efficient resource utilization.
  # Messages can also be prioritized, ensuring that higher-priority tasks are processed first.
  #
  # @note: While the Station provides a robust mechanism for background processing,
  #        it's important to understand that the exact timing of message processing is not controlled by the publisher,
  #        and messages will be processed as resources become available.
  class Station
    include MonitorMixin

    class CapacityError < StandardError; end

    # Constructor
    #
    # @note Delays process exit in an attempt to flush the queue to avoid dropping messages.
    #       Exit flushing makes a "best effort" to process all messages, but it's not guaranteed.
    #       Will not delay process exit when the queue is empty.
    #
    # @rbs bus: Bus -- local message bus (default: Bus.new)
    # @rbs interval: Float -- queue polling interval in seconds (default: 0.1)
    # @rbs limit: Integer -- max queue size (default: 10_000)
    # @rbs threads: Integer -- number of threads to use (default: Etc.nprocessors)
    # @rbs timeout: Float -- seconds to wait for subscribers to process the message before cancelling (default: 60)
    # @rbs wait: Float -- seconds to wait for the queue to flush at process exit (default: 5)
    # @rbs return: void
    def initialize(bus: Bus.new, interval: 0.1, limit: 10_000, threads: Etc.nprocessors, timeout: 60, wait: 5)
      super()
      @bus = bus
      @interval = interval.to_f
      @interval = 0.1 unless @interval.positive?
      @limit = limit.to_i.positive? ? limit.to_i : 10_000
      @threads = [threads.to_i, 1].max
      @timeout = timeout.to_f
      @queue = Containers::PriorityQueue.new
      at_exit { stop timeout: [wait.to_f, 1].max }
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
    attr_reader :limit

    # Number of threads to use
    # @rbs return: Integer
    attr_reader :threads

    # Default timeout for message processing (in seconds)
    # @rbs return: Float
    attr_reader :timeout

    # Starts the station
    # @rbs interval: Float -- queue polling interval in seconds (default: self.interval)
    # @rbs threads: Integer -- number of threads to use (default: self.threads)
    # @rbs return: void
    def start(interval: self.interval, threads: self.threads)
      interval = 0.1 unless interval.positive?
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

    # Indicates if the queue is empty
    # @rbs return: bool
    def empty?
      synchronize { @queue.empty? }
    end

    # Number of unprocessed messages in the queue
    # @rbs return: Integer
    def count
      synchronize { @queue.size }
    end

    # Subscribe to a topic
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- callable that will process messages published to the topic
    # @rbs &block: (Message) -> untyped -- alternative way to provide a callable
    # @rbs return: self
    def subscribe(...)
      bus.subscribe(...)
      self
    end

    # Unsubscribes a callable from a topic
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- subscriber that should no longer receive messages
    # @rbs return: self
    def unsubscribe(...)
      bus.unsubscribe(...)
      self
    end

    # Unsubscribes all subscribers from a topic and removes the topic
    # @rbs topic: String -- topic name
    # @rbs return: self
    def unsubscribe_all(...)
      bus.unsubscribe_all(...)
      self
    end

    # Publishes a message
    #
    # @rbs topic: String | Symbol -- topic name
    # @rbs priority: Integer -- priority of the message, higher number == higher priority (default: 1)
    # @rbs timeout: Float -- seconds to wait before cancelling
    # @rbs payload: Hash[Symbol, untyped] -- message payload
    # @rbs return: Message
    def publish(topic, priority: 1, timeout: self.timeout, **payload)
      publish_message Message.new(topic, timeout: timeout, **payload), priority: priority
    end

    # Publishes a pre-built message
    # @rbs message: Message -- message to publish
    # @rbs return: Message
    def publish_message(message, priority: 1)
      synchronize do
        raise CapacityError, "Station is at capacity! (limit: #{limit})" if @queue.size >= limit
        @queue.push message, priority
      end
    end
  end
end
