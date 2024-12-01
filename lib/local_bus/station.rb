# frozen_string_literal: true

# rbs_inline: enabled
# rubocop:disable Lint/MissingCopEnableDirective
# rubocop:disable Style/ArgumentsForwarding

class LocalBus
  # An in-process message queuing system that buffers and publishes messages to Bus.
  # This class acts as an intermediary, queuing messages internally before publishing them to the Bus.
  #
  # @note Station shares the same interface as Bus and is thus a message bus.
  #       The key difference is that Stations are multi-threaded and will not block the main thread.
  #
  # Three fallback policies are supported:
  # 1. `abort` - Raises an exception and discards the task when the queue is full (default)
  # 2. `discard` - Discards the task when the queue is full
  # 3. `caller_runs` - Executes the task on the calling thread when the queue is full,
  #                 This effectively jumps the queue (and blocks the main thread) but ensures the task is performed
  #
  # IMPORTANT: Be sure to release resources like database connections in subscribers when publishing via Station.
  #
  class Station
    include MonitorMixin

    class QueueFullError < StandardError; end

    # Constructor
    # @rbs bus: Bus -- local message bus (default: Bus.new)
    # @rbs interval: Float -- queue polling interval in seconds (default: 0.01)
    # @rbs size: Integer -- max queue size (default: 10_000)
    # @rbs threads: Integer -- number of threads to use (default: Etc.nprocessors)
    # @rbs timeout: Float -- seconds to wait for a published message to complete
    # @rbs return: void
    def initialize(bus: Bus.new, interval: 0.01, size: 10_000, threads: Etc.nprocessors, timeout: 60)
      super()
      @bus = bus
      @interval = interval.to_f
      @size = size.to_i
      @threads = threads.to_i
      @timeout = timeout.to_f
      @queue = Containers::PriorityQueue.new
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
      synchronize do
        return if running? || stopping?

        # Supervisor thread that orchestrates the worker pool
        @thread = Thread.new do
          size = (threads >= 2) ? threads - 1 : 1
          pool = Async::WorkerPool.new(size: size)

          threads.times do
            pool.call -> do
              timers = Timers::Group.new
              timers.every interval do
                bus.send :publish_message, @queue.pop unless @queue.empty?
              end

              loop do
                break if stopping?
                timers.wait
              end

              timers.cancel
            end
          end

          Thread.current[:pool] = pool
        end
      end
    end

    # Stops the station
    # @rbs return: void
    def stop
      synchronize do
        return unless running?
        return if stopping?
        @stopping = true
      end
      @thread[:pool]&.close
      @thread&.join
    ensure
      @stopping = false
      @thread = nil
    end

    def stopping?
      synchronize { !!@stopping }
    end

    # Indicates if the station is running
    # @rbs return: bool
    def running?
      synchronize { !!@thread }
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
      synchronize do
        raise QueueFullError, "Queue is at capacity! #{size}" if @queue.size >= size
        Message.new(topic, timeout: timeout, **payload).tap do |message|
          @queue.push message, priority
        end
      end
    end
  end
end
