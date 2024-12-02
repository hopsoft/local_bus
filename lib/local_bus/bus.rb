# frozen_string_literal: true

# rbs_inline: enabled

class LocalBus
  # Local in-process single threaded "message bus" with non-blocking I/O
  class Bus
    include MonitorMixin

    # Constructor
    # @note Creates a new Bus instance with specified max concurrency (i.e. number of tasks that can run in parallel)
    # @rbs concurrency: Integer -- maximum number of concurrent tasks (default: Etc.nprocessors)
    def initialize(concurrency: Etc.nprocessors)
      super()
      @concurrency = concurrency.to_i
      @subscriptions = Hash.new do |hash, key|
        hash[key] = Set.new
      end
    end

    # Maximum number of concurrent tasks that can run in "parallel"
    # @rbs return: Integer
    def concurrency
      synchronize { @concurrency }
    end

    # Sets the max concurrency
    # @rbs value: Integer -- max number of concurrent tasks that can run in "parallel"
    # @rbs return: Integer -- new concurrency value
    def concurrency=(value)
      synchronize { @concurrency = value.to_i }
    end

    # Registered topics that have subscribers
    # @rbs return: Array[String] -- list of topic names
    def topics
      synchronize { @subscriptions.keys }
    end

    # Registered subscriptions
    # @rbs return: Hash[String, Array[callable]] -- mapping of topics to callables
    def subscriptions
      synchronize do
        @subscriptions.each_with_object({}) do |(topic, callables), memo|
          memo[topic] = callables.to_a
        end
      end
    end

    # Subscribes a callable to a topic
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- callable that will process messages published to the topic
    # @rbs &block: (Message) -> untyped -- alternative way to provide a callable
    # @rbs return: self
    # @raise [ArgumentError] if neither callable nor block is provided
    def subscribe(topic, callable: nil, &block)
      callable ||= block
      raise ArgumentError, "Subscriber must respond to #call" unless callable.respond_to?(:call, false)
      synchronize { @subscriptions[topic.to_s].add callable }
      self
    end

    # Unsubscribes a callable from a topic
    # @rbs topic: String -- topic name
    # @rbs callable: (Message) -> untyped -- subscriber that should no longer receive messages
    # @rbs return: self
    def unsubscribe(topic, callable:)
      topic = topic.to_s
      synchronize do
        @subscriptions[topic].delete callable
        @subscriptions.delete(topic) if @subscriptions[topic].empty?
      end
      self
    end

    # Unsubscribes all subscribers from a topic and removes the topic
    # @rbs topic: String -- topic name
    # @rbs return: self
    def unsubscribe_all(topic)
      topic = topic.to_s
      synchronize do
        @subscriptions[topic].clear
        @subscriptions.delete topic
      end
      self
    end

    # Executes a block and unsubscribes all subscribers from the topic afterwards
    # @rbs topic: String -- topic name
    # @rbs block: (String) -> void -- block to execute (yields the topic)
    def with_topic(topic, &block)
      block.call topic.to_s
    ensure
      unsubscribe_all topic
    end

    # Publishes a message to a topic
    #
    # @note If subscribers are rapidly created/destroyed mid-publish, there's a theoretical
    #       possibility of object_id reuse. However, this is extremely unlikely in practice.
    #
    #       * If subscribers are added mid-publish, they will not receive the message
    #       * If subscribers are removed mid-publish, they will still receive the message
    #
    # @note If the timeout is exceeded, the task will be cancelled before all subscribers have completed.
    #
    # Check individual Subscribers for possible errors.
    #
    # @rbs topic: String -- topic name
    # @rbs timeout: Float -- seconds to wait for subscribers to process the message before cancelling (default: 60)
    # @rbs payload: Hash -- message payload
    # @rbs return: Message
    def publish(topic, timeout: 60, **payload)
      publish_message Message.new(topic, timeout: timeout.to_f, **payload)
    end

    private

    # Publishes a message to the queue
    # @rbs return: Message
    def publish_message(message)
      barrier = Async::Barrier.new
      subscribers = subscriptions.fetch(message.topic, []).map { Subscriber.new _1, message }

      if subscribers.any?
        Sync do |task|
          task.with_timeout message.timeout do
            semaphore = Async::Semaphore.new(concurrency, parent: barrier)

            subscribers.each do |subscriber|
              semaphore.async do
                subscriber.perform
              end
            end
          rescue Async::TimeoutError => cause
            barrier.stop

            subscribers.select(&:pending?).each do |subscriber|
              subscriber.timeout cause
            end
          end
        end
      end

      message.publication = Publication.new(barrier, *subscribers)
      message
    end
  end
end
