# frozen_string_literal: true

class LocalBus
  # Represents a message in the LocalBus system
  class Message
    # Constructor
    # @note Creates a new Message instance with the given topic and payload
    # @rbs topic: String -- the topic of the message
    # @rbs timeout: Float? -- optional timeout for message processing (in seconds)
    # @rbs payload: Hash -- the message payload
    def initialize(topic, timeout: nil, **payload)
      @id = SecureRandom.uuid_v7
      @topic = topic.to_s.freeze
      @payload = payload.transform_keys(&:to_sym).freeze
      @created_at = Time.now
      @thread_id = Thread.current.object_id
      @timeout = timeout.to_f
      @metadata ||= {
        id: id,
        topic: topic,
        payload: payload,
        created_at: created_at,
        thread_id: thread_id,
        timeout: timeout
      }.freeze
      freeze
    end

    # Unique identifier for the message
    # @rbs return: String
    attr_reader :id

    # Message topic
    # @rbs return: String
    attr_reader :topic

    # Message payload
    # @rbs return: Hash
    attr_reader :payload

    # Time when the message was created or published
    # @rbs return: Time
    attr_reader :created_at

    # ID of the thread that created the message
    # @rbs return: Integer
    attr_reader :thread_id

    # Timeout for message processing (in seconds)
    # @rbs return: Float
    attr_reader :timeout

    # Metadata for the message
    # @rbs return: Hash[Symbol, untyped]
    attr_reader :metadata

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
