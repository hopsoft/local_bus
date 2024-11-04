# frozen_string_literal: true

require_relative "test_helper"

class LocalBus
  class StationTest < Minitest::Test
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

      result = station.publish("example", station: true)
      result.wait
      subscribers = result.value

      assert_kind_of Concurrent::Promises::Future, result
      assert subscribers.all? { _1 in LocalBus::Subscriber }
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

    def test_publish_and_chain_futures_with_then
      station = Station.new

      station.subscribe(@topic) do |message|
        sleep 0.1 # simulated latency
        :test
      end

      # chain futures with #then
      # @note #then blocks can return any value, but #publish always returns Subscriber
      future = station.publish(@topic, success: true).then do |results|
        sleep 0.1 # simulated latency
        results << {thread_id: Thread.current.object_id}
      end

      values = future.value # block and wait for the futures to complete
      result = values[0] # this is a Subscriber
      value = values[1] # this is the value returned by the #then block

      refute_equal Thread.current.object_id, result.metadata[:thread_id]
      refute_equal Thread.current.object_id, value[:thread_id]
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

      ap duration: Time.now - start
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

      future = station.publish(@topic, timeout: latency) # Concurrent::Promises::Future
      subscribers = future.value # SubscriberList

      assert_pattern { subscribers.first => {error: nil, metadata: {**}} }
      assert_pattern { subscribers.last => {error: LocalBus::Subscriber::Error, metadata: {**}} }
      assert subscribers.last.error.message.start_with? "Timeout expired before invocation!"
      assert subscribers.last.error.cause.is_a? Async::TimeoutError
    end
  end
end
