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
      errored_subscribers = subscribers.select(&:errored?)
      successful_subscribers = subscribers.reject(&:errored?)

      assert_equal 2, subscribers.size
      assert_equal 1, errored_subscribers.size
      assert_equal 1, successful_subscribers.size
    end

    def test_publish_with_multiple_subscribers
      received_messages = []
      station = Station.new

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

    def test_publish_with_priority
      station = Station.new(threads: 1)
      station.stop # stop the queue so we can add messages now and process later

      index = 0
      station.subscribe("default") { index += 1 }
      station.subscribe("important") { index += 1 }
      station.subscribe("critical") { index += 1 }

      # note the order of publications
      default = station.publish("default")
      important = station.publish("important", priority: 5)
      critical = station.publish("critical", priority: 10)

      station.start
      default.wait # only need to wait for the lowest priority as higher priority messages will process first

      default_subscriber = default.subscribers.first
      important_subscriber = important.subscribers.first
      critical_subscriber = critical.subscribers.first

      assert_equal 1, critical_subscriber.value
      assert critical_subscriber.metadata[:finished_at] < important_subscriber.metadata[:finished_at]

      assert_equal 2, important_subscriber.value
      assert important_subscriber.metadata[:finished_at] < default_subscriber.metadata[:finished_at]

      assert_equal 3, default_subscriber.value
    end

    def test_stop_with_unprocessed_messages
      station = Station.new
      count = 30
      latency = 0.1

      count.times do |i|
        station.bus.concurrency.times do
          station.subscribe("topic-#{i}") { sleep latency }
        end
        station.publish("topic-#{i}")
      end

      sleep latency * 2 # allow time for some messages to process but not all
      station.stop

      # should have some unprocessed messages
      refute station.empty?
      assert station.count < count

      # resume processing
      station.start
      sleep latency * 2 # allow time for remaining messages to process
      assert station.empty?
    end
  end
end
