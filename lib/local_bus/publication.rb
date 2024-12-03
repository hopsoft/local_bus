# frozen_string_literal: true

# rbs_inline: enabled

class LocalBus
  # Wraps an Async::Barrier and a list of Subscribers that are processing a Message.
  class Publication
    # Constructor
    # @rbs barrier: Async::Barrier -- barrier used to wait for all subscribers
    # @rbs subscribers: Array[Subscriber]
    def initialize(barrier, *subscribers)
      @barrier = barrier
      @subscribers = subscribers
    end

    # Blocks and waits for the barrier (i.e. all subscribers to complete)
    # @rbs return: void
    def wait
      @barrier.wait
      self
    end

    # List of Subscribers that are processing a Message
    # @note Blocks until all subscribers complete
    # @rbs return: Array[Subscriber]
    def subscribers
      wait
      @subscribers
    end
  end
end
