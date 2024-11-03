# frozen_string_literal: true

class LocalBus
  # Wraps an Async::Barrier and a list of Subscribers.
  # Delegates #wait to the barrier and all other methods to the subscriber list.
  class Monitor
    # Constructor
    # @rbs barrier: Async::Barrier -- barrier used to wait for all tasks
    # @rbs subscribers: Array[Subscriber]
    def initialize(barrier, *subscribers)
      @barrier = barrier
      @subscribers = subscribers
    end

    # Waits for the barrier (i.e. subscribers to complete)
    # @rbs return: void
    def wait
      @barrier.wait
      self
    end

    # @!group Delegatation to subscribers

    def method_missing(...)
      return @subscribers.send(...) if @subscribers.respond_to?(...)
      super
    end

    def respond_to_missing?(...)
      return true if @subscribers.respond_to?(...)
      super
    end
  end
end
