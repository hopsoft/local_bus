# frozen_string_literal: true

# rbs_inline: enabled

class LocalBus
  # Wraps a Callable (Proc) and Message intended for asynchronous execution.
  class Subscriber
    # Custom error class for Subscriber errors
    class Error < StandardError
      # Constructor
      # @rbs message: String -- error message
      # @rbs cause: StandardError? -- underlying cause of the error
      def initialize(message, cause:)
        super(message)
        @cause = cause
      end

      # Underlying cause of the error
      # @rbs return: StandardError?
      attr_reader :cause
    end

    # Constructor
    # @rbs callable: #call -- the subscriber's callable object
    # @rbs message: Message -- the message to be processed
    def initialize(callable, message)
      @callable = callable
      @message = message
      @id = callable.object_id
      @source_location = case callable
      in Proc then callable.source_location
      else callable.method(:call).source_location
      end
      @metadata = {}
    end

    # Unique identifier for the subscriber
    # @rbs return: String
    attr_reader :id

    # Source location of the callable
    # @rbs return: Array[String, Integer]?
    attr_reader :source_location

    # Callable object -- Proc, lambda, etc. (must respond to #call)
    # @rbs return: #call
    attr_reader :callable

    # Error if the subscriber fails (available after performing)
    # @rbs return: Error?
    attr_reader :error

    # Message for the subscriber to process
    # @rbs return: Message
    attr_reader :message

    # Metadata for the subscriber (available after performing)
    # @rbs return: Hash[Symbol, untyped]
    attr_reader :metadata

    # Value returned by the callable (available after performing)
    # @rbs return: untyped
    attr_reader :value

    # Indicates if the subscriber has been performed
    # @rbs return: bool
    def performed?
      metadata.any?
    end

    # Checks if the subscriber is pending
    # @rbs return: bool
    def pending?
      metadata.empty?
    end

    # Performs the subscriber's callable
    # @rbs return: void
    def perform
      return if performed?

      with_metadata do
        @value = callable.call(message)
      rescue => cause
        @error = Error.new("Invocation failed! #{cause.message}", cause: cause)
      end
    end

    # Handles timeout for the subscriber
    # @rbs cause: StandardError -- the cause of the timeout
    # @rbs return: void
    def timeout(cause)
      return if performed?

      with_metadata do
        @error = Error.new("Timeout expired before invocation! Waited #{message.timeout} seconds!", cause: cause)
      end
    end

    # Returns the subscriber's data as a hash
    # @rbs return: Hash[Symbol, untyped]
    def to_h
      {
        error: error,
        metadata: metadata,
        value: value
      }
    end

    # Allows pattern matching on subscriber attributes
    # @rbs keys: Array[Symbol] -- keys to extract from the subscriber
    # @rbs return: Hash[Symbol, untyped]
    def deconstruct_keys(keys)
      keys.any? ? to_h.slice(*keys) : to_h
    end

    private

    # Captures metadata for the subscriber's performance
    # @rbs return: void
    def with_metadata
      started_at = Time.now
      yield
      @metadata = {
        id: SecureRandom.uuid_v7,
        thread_id: Thread.current.object_id,
        source_location: source_location,
        started_at: started_at,
        finished_at: Time.now,
        duration: Time.now - started_at,
        latency: Time.now - message.created_at,
        message: message
      }.freeze
    end
  end
end
