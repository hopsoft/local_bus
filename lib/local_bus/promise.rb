# frozen_string_literal: true

# rbs_inline: enabled

class LocalBus
  # Wraps an Async::Barrier and a list of Subscribers.
  # Delegates #wait to the barrier and all other methods to the subscriber list.
  class Promise
    # Constructor
    # @rbs barrier: Async::Barrier -- barrier used to wait for all tasks
    # @rbs subscribers: Array[Subscriber]
    def initialize(barrier, *subscribers)
      @barrier = barrier
      @subscribers = subscribers
    end

    # Blocks and waits for the barrier... all subscribers to complete
    # @rbs return: void
    def wait
      @barrier.wait
      self
    end

    # Blocks and waits then returns all subscribers
    # @rbs return: Array[Subscriber]
    def value
      wait
      @subscribers
    end
  end
end
