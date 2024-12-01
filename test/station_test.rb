# frozen_string_literal: true

require_relative "test_helper"

class LocalBus
  class StationTest < Minitest::Test
    class TestCallable
      def call(message)
        message.payload
      end
    end

    def setup
      @topic = "test"
      @latency = 0.25
    end

    def test_implicitly_starts
      station = Station.new
      assert station.running?
    end

    def test_stop
      station = Station.new
      station.stop
      refute station.running?
    end

    def test_publish
      station = Station.new
      station.subscribe "example" do |message|
        sleep 0.1
        {received: message.payload}
      end

      message = station.publish("example", station: true)
      message.wait
      subscribers = message.subscribers

      assert subscribers.all? { _1 in LocalBus::Subscriber }
      assert_pattern { subscribers => [{value: {received: {station: true}}}] }
    end

    def test_publish_with_callable_object
      station = Station.new
      station.bus.concurrency.times do |num|
        station.subscribe @topic, callable: TestCallable.new
      end

      message = station.publish(@topic, number: rand(10))
      subscribers = message.subscribers

      assert_equal station.bus.concurrency, subscribers.size
      assert subscribers.all? { _1 in Subscriber }
      assert subscribers.map(&:value).all? { _1[:number] in Integer }
    end

    def test_publish_and_wait_with_1_subscriber
      station = Station.new

      # @note MessageBus subscribers run on separate thread when using Station
      received_message = nil
      station.subscribe(@topic) do |message|
        received_message = message
      end

      # @note publishes to Bus on separate thread when using Station
      future = station.publish @topic, success: true
      #                           │    └────┬──────┘
      #                           │         └ message payload sent to callables
      #                           │           subscribed to the topic
      #                           │
      #                           └ subscribed callables are wrapped in a Subscriber and
      #                             invoked when messages are published to topics

      future.wait # block and wait for the future to complete (can also use #value)

      assert_equal({success: true}, received_message.payload)
    end

    def test_mixed_subscribers
      station = Station.new
      station.subscribe "user.created" do |message|
        raise "Something went wrong!"
      end

      station.subscribe "user.created" do |message|
        # This still executes despite the error above
        true
      end

      # The publish operation completes with partial success
      message = station.publish("user.created", user_id: 123)
      subscribers = message.subscribers
      errored_subscribers = subscribers.select(&:error)
      successful_subscribers = subscribers.reject(&:error)

      assert_equal 2, subscribers.size
      assert_equal 1, errored_subscribers.size
      assert_equal 1, successful_subscribers.size
    end

    def test_publish_with_multiple_subscribers
      received_messages = []
      station = Station.new

      # @note This loop takes 10 seconds to complete without non-blocking IO
      start = Time.now
      100.times do
        station.subscribe(@topic) do |message|
          sleep 0.1 # simulated latency
          received_messages << message
        end
      end

      station.publish(@topic, success: true).wait

      assert Time.now - start < 6 # 1.5 (adjusted for GitHub Actions which are slow as hell)
      assert_equal 100, received_messages.size
      assert received_messages.all? { _1.payload == {success: true} }
    end

    def test_publish_with_timeout
      latency = 0.25
      concurrency = 2
      bus = Bus.new(concurrency: concurrency)
      station = Station.new(bus: bus)

      (concurrency * 2).times do |i|
        station.subscribe(@topic) do |message|
          sleep i.zero? ? latency / 2 : latency * 2
          true
        end
      end

      message = station.publish(@topic, timeout: latency)
      subscribers = message.subscribers

      assert_pattern { subscribers.first => {error: nil, metadata: {**}} }
      assert_pattern { subscribers.last => {error: LocalBus::Subscriber::Error, metadata: {**}} }
      assert subscribers.last.error.message.start_with? "Timeout expired before invocation!"
      assert subscribers.last.error.cause.is_a? Async::TimeoutError
    end
  end
end
