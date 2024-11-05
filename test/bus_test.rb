# frozen_string_literal: true

require_relative "test_helper"

class LocalBus
  class BusTest < Minitest::Test
    class TestCallable
      def call(message)
        message.payload
      end
    end

    def setup
      @topic = "test"
      @latency = 0.25
    end

    def test_subscribers_must_be_callable
      bus = Bus.new
      assert_raises(ArgumentError) { bus.subscribe @topic, callable: nil }
      assert_raises(ArgumentError) { bus.subscribe @topic, callable: "invalid" }
      assert_raises(ArgumentError) { bus.subscribe @topic, callable: :invalid }
      assert_raises(ArgumentError) { bus.subscribe @topic, callable: Object.new }
    end

    def test_subscribe
      bus = Bus.new
      subscriber = -> {}
      bus.subscribe @topic, callable: subscriber

      assert_equal 1, bus.topics.size
      assert_equal [@topic], bus.topics
      assert_equal 1, bus.subscriptions.size
      assert_equal 1, bus.subscriptions[@topic].size
      assert bus.subscriptions[@topic].member?(subscriber)
    end

    def test_unsubscribe
      bus = Bus.new
      subscriber = -> {}

      bus.subscribe @topic, callable: subscriber
      refute_empty bus.subscriptions[@topic]
      assert bus.subscriptions[@topic].member?(subscriber)

      bus.unsubscribe @topic, callable: subscriber
      assert_nil bus.subscriptions[@topic]
    end

    def test_publish
      bus = Bus.new

      bus.concurrency.times do |num|
        bus.subscribe(@topic) do |_message|
          sleep @latency
          num
        end
      end

      start = Time.now
      result = bus.publish(@topic)
      result.wait
      subscribers = result.value

      assert result.value.all? { _1 in LocalBus::Subscriber }
      assert_equal (0..bus.concurrency - 1).to_a, subscribers.map(&:value)
      assert (@latency...(@latency * 1.25)).cover?(Time.now - start)
    end

    def test_publish_with_callable_object
      bus = Bus.new
      bus.concurrency.times do |num|
        bus.subscribe @topic, callable: TestCallable.new
      end

      subscribers = bus.publish(@topic, number: rand(10)).value

      assert_equal bus.concurrency, subscribers.size
      assert subscribers.all? { _1 in Subscriber }
      assert subscribers.map(&:value).all? { _1[:number] in Integer }
    end

    def test_subscriber_signature
      bus = Bus.new
      received_message = nil

      bus.subscribe(@topic) do |message|
        received_message = message
      end

      bus.publish(@topic, test: true)

      assert_pattern { received_message => {payload: {test: true}} }
    end

    def test_subscriber_errors
      bus = Bus.new

      bus.concurrency.times do |num|
        bus.subscribe @topic do |_message|
          raise "Intentional Error!"
        end
      end

      promise = bus.publish(@topic, test: true)
      promise.wait
      subscribers = promise.value

      assert_equal bus.concurrency, bus.subscriptions[@topic].size
      assert_equal bus.concurrency, subscribers.size
      assert subscribers.all? { _1.error in Subscriber::Error }
      assert subscribers.all? { _1.error.message.start_with? "Invocation failed!" }
      assert subscribers.all? { _1.error.cause.message.start_with? "Intentional Error!" }
    end

    def test_timeout
      bus = Bus.new

      count = bus.concurrency * 2
      count.times do |index|
        bus.subscribe(@topic) do |_message|
          sleep @latency
          index
        end
      end
      assert_equal count, bus.subscriptions[@topic].size

      subscribers = bus.publish(@topic, timeout: @latency, test: true).value
      assert_equal count, subscribers.size

      pending = subscribers.select(&:pending?)
      assert_equal 0, pending.size

      performed = subscribers.select(&:performed?)
      assert_equal count, performed.size

      # asserts some successful subscriber invocations
      successful = performed.select { _1.error.nil? }
      assert successful.any?

      # asserts some unsuccessful subscriber invocations
      unsuccessful = performed.select { _1.error }
      assert unsuccessful.any?
      assert unsuccessful.all? { _1.error.message.start_with? "Timeout expired before invocation!" }
      assert unsuccessful.all? { _1.error.cause in Async::TimeoutError }
    end
  end
end
