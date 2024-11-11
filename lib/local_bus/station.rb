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

    class TimeoutError < StandardError; end

    # Default options for Concurrent::FixedThreadPool (can be overridden via the constructor)
    # @see https://ruby-concurrency.github.io/concurrent-ruby/1.3.4/Concurrent/ThreadPoolExecutor.html
    THREAD_POOL_OPTIONS = {
      max_queue: 5_000, # max number of pending tasks allowed in the queue
      fallback_policy: :caller_runs # Options: :abort, :discard, :caller_runs
    }.freeze

    # Constructor
    # @rbs bus: Bus -- local message bus (default: Bus.new)
    # @rbs max_threads: Integer -- number of max_threads (default: Concurrent.processor_count)
    # @rbs default_timeout: Float -- seconds to wait for a future to complete
    # @rbs shutdown_timeout: Float -- seconds to wait for all futures to complete on process exit
    # @rbs options: Hash[Symbol, untyped] -- Concurrent::FixedThreadPool options
    # @rbs return: void
    def initialize(
      bus: Bus.new,
      max_threads: Concurrent.processor_count,
      default_timeout: 0,
      shutdown_timeout: 8,
      **options
    )
      super()
      @bus = bus
      @max_threads = [2, max_threads].max.to_i
      @default_timeout = default_timeout.to_f
      @shutdown_timeout = shutdown_timeout.to_f
      @shutdown = Concurrent::AtomicBoolean.new(false)
      start(**options)
    end

    # Bus instance
    # @rbs return: Bus
    attr_reader :bus

    # Number of threads used to process messages
    # @rbs return: Integer
    attr_reader :max_threads

    # Default timeout for message processing (in seconds)
    # @rbs return: Float
    attr_reader :default_timeout

    # Timeout for graceful shutdown (in seconds)
    # @rbs return: Float
    attr_reader :shutdown_timeout

    # Starts the broker
    # @rbs options: Hash[Symbol, untyped] -- Concurrent::FixedThreadPool options
    # @rbs return: void
    def start(**options)
      synchronize do
        return if running?

        start_shutdown_handler
        @pool = Concurrent::FixedThreadPool.new(max_threads, THREAD_POOL_OPTIONS.merge(options))
        enable_safe_shutdown on: ["HUP", "INT", "QUIT", "TERM"]
      end
    end

    # Stops the broker
    # @rbs timeout: Float -- seconds to wait for all futures to complete
    # @rbs return: void
    def stop(timeout: shutdown_timeout)
      return unless @shutdown.make_true # Ensure we only stop once

      synchronize do
        if running?
          # First try graceful shutdown
          pool.shutdown

          # If graceful shutdown fails, force termination
          pool.kill unless pool.wait_for_termination(timeout)

          @pool = nil
        end
      rescue
        nil # ignore errors during shutdown
      end

      # Clean up shutdown handler
      if @shutdown_thread&.alive?
        @shutdown_queue&.close
        @shutdown_thread&.join timeout
      end

      @shutdown_thread = nil
      @shutdown_queue = nil
      @shutdown_completed&.set
    end

    # Indicates if the broker is running
    # @rbs return: bool
    def running?
      synchronize { pool&.running? }
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

    # Publishes a message to Bus on a separate thread keeping the main thread free for additional work.
    #
    # @note This allows you to publish messages when performing operations like handling web requests
    #       without blocking the main thread and slowing down the response.
    #
    # @see https://ruby-concurrency.github.io/concurrent-ruby/1.3.4/Concurrent/Promises/Future.html
    #
    # @rbs topic: String | Symbol -- topic name
    # @rbs timeout: Float -- seconds to wait before cancelling
    # @rbs payload: Hash[Symbol, untyped] -- message payload
    # @rbs return: Concurrent::Promises::Future
    def publish(topic, timeout: default_timeout, **payload)
      timeout = timeout.to_f

      future = Concurrent::Promises.future_on(pool) do
        case timeout
        in 0 then bus.publish(topic, **payload).value
        else bus.publish(topic, timeout: timeout, **payload).value
        end
      end

      # ensure calls to future.then use the thread pool
      executor = pool
      future.singleton_class.define_method :then do |&block|
        future.then_on(executor, &block)
      end

      future
    end

    private

    # Thread pool used for asynchronous operations
    # @rbs return: Concurrent::FixedThreadPool
    attr_reader :pool

    # Starts the shutdown handler thread
    # @rbs return: void
    def start_shutdown_handler
      return if @shutdown.true?

      @shutdown_queue = Queue.new
      @shutdown_completed = Concurrent::Event.new
      @shutdown_thread = Thread.new do
        catch :shutdown do
          loop do
            signal = @shutdown_queue.pop # blocks until something is available
            throw :shutdown if @shutdown_queue.closed?

            stop # initiate shutdown sequence

            # Re-raise the signal to let the process terminate
            if signal
              # Remove our trap handler before re-raising
              trap signal, "DEFAULT"
              Process.kill signal, Process.pid
            end
          rescue ThreadError, ClosedQueueError
            break # queue was closed, exit gracefully
          end
        end
        @shutdown_completed.set
      end
    end

    # Enables safe shutdown on process exit by trapping specified signals
    # @rbs on: Array[String] -- signals to trap
    # @rbs return: void
    def enable_safe_shutdown(on:)
      at_exit { stop }
      on.each do |signal|
        trap signal do
          @shutdown_queue.push signal unless @shutdown.true?
        rescue
          nil
        end
      end
    end
  end
end
