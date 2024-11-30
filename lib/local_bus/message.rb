# frozen_string_literal: true

# rbs_inline: enabled

class LocalBus
  # Represents a message in the LocalBus system
  class Message
    # Constructor
    # @note Creates a new Message instance with the given topic and payload
    # @rbs topic: String -- the topic of the message
    # @rbs timeout: Float? -- optional timeout for message processing (in seconds)
    # @rbs payload: Hash -- the message payload
    def initialize(topic, timeout: nil, **payload)
      @metadata ||= {
        id: SecureRandom.uuid_v7,
        topic: topic.to_s.freeze,
        payload: payload.transform_keys(&:to_sym).freeze,
        created_at: Time.now,
        thread_id: Thread.current.object_id,
        timeout: timeout.to_f
      }.freeze
    end

    # Metadata for the message
    # @rbs return: Hash[Symbol, untyped]
    attr_reader :metadata

    # Promise processing the message
    # @note May be nil if processing hasn't started (e.g. it was published via Station)
    # @rbs return: Promise?
    attr_accessor :promise

    # Unique identifier for the message
    # @rbs return: String
    def id
      metadata[:id]
    end

    # Message topic
    # @rbs return: String
    def topic
      metadata[:topic]
    end

    # Message payload
    # @rbs return: Hash
    def payload
      metadata[:payload]
    end

    # Time when the message was created or published
    # @rbs return: Time
    def created_at
      metadata[:created_at]
    end

    # ID of the thread that created the message
    # @rbs return: Integer
    def thread_id
      metadata[:thread_id]
    end

    # Timeout for message processing (in seconds)
    # @rbs return: Float
    def timeout
      metadata[:timeout]
    end

    # Blocks and waits for the message to process
    # @rbs interval: Float -- time to wait between checks (default: 0.1)
    # @rbs return: void
    def wait(interval: 0.1)
      @timers ||= Timers::Group.new.tap do |t|
        t.every(interval) {}
        loop do
          t.wait
          break if promise
        end
      end
      promise.wait
    ensure
      @timers&.cancel
      @timers = nil
    end

    # Blocks and waits for the message process then returns all subscribers
    # @rbs return: Array[Subscriber]
    def subscribers
      wait
      promise.value
    end

    # Converts the message to a hash
    # @rbs return: Hash[Symbol, untyped]
    alias_method :to_h, :metadata

    # Allows pattern matching on message attributes
    # @rbs keys: Array[Symbol] -- keys to extract from the message
    # @rbs return: Hash[Symbol, untyped]
    def deconstruct_keys(keys)
      keys.any? ? to_h.slice(*keys) : to_h
    end
  end
end
