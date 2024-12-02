<p align="center">
  <a href="http://blog.codinghorror.com/the-best-code-is-no-code-at-all/">
    <img alt="Lines of Code" src="https://img.shields.io/badge/loc-341-47d299.svg" />
  </a>
  <a href="https://rubygems.org/gems/local_bus">
    <img alt="GEM Version" src="https://img.shields.io/gem/v/local_bus">
  </a>
  <a href="https://rubygems.org/gems/local_bus">
    <img alt="GEM Downloads" src="https://img.shields.io/gem/dt/local_bus">
  </a>
  <a href="https://github.com/hopsoft/local_bus/actions">
    <img alt="Tests" src="https://github.com/hopsoft/local_bus/actions/workflows/tests.yml/badge.svg" />
  </a>
  <a href="https://github.com/testdouble/standard">
    <img alt="Ruby Style" src="https://img.shields.io/badge/style-standard-168AFE?logo=ruby&logoColor=FE1616" />
  </a>
  <a href="https://github.com/sponsors/hopsoft">
    <img alt="Sponsors" src="https://img.shields.io/github/sponsors/hopsoft?color=eb4aaa&logo=GitHub%20Sponsors" />
  </a>
  <a href="https://twitter.com/hopsoft">
    <img alt="Twitter Follow" src="https://img.shields.io/twitter/url?label=%40hopsoft&style=social&url=https%3A%2F%2Ftwitter.com%2Fhopsoft">
  </a>
</p>

# LocalBus

LocalBus is a lightweight pub/sub system for Ruby that helps organize and simplify intra-process communication.

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Why LocalBus?](#why-localbus)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
    - [Interfaces](#interfaces)
    - [Bus (immediate processing)](#bus-immediate-processing)
    - [Station (background processing)](#station-background-processing)
  - [Advanced Usage & Considerations](#advanced-usage--considerations)
    - [Concurrency Controls](#concurrency-controls)
      - [Bus Interface](#bus-interface)
      - [Station Interface](#station-interface)
        - [Message Priority](#message-priority)
    - [Error Handling & Recovery](#error-handling--recovery)
    - [Memory Considerations](#memory-considerations)
    - [Blocking Operations](#blocking-operations)
    - [Shutdown & Cleanup](#shutdown--cleanup)
    - [Limitations](#limitations)
  - [See Also](#see-also)
  - [Sponsors](#sponsors)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Why LocalBus?

A message bus (or enterprise service bus) is an architectural pattern that enables different parts of an application to communicate without direct knowledge of each other. Think of it as a smart postal service for your application - components can send messages to topics, and other components can listen for those messages, all without knowing about each other directly.

Even within a single process, this pattern offers powerful benefits:

- **Decouple Components**: Break complex systems into maintainable parts that can evolve independently
- **Single Responsibility**: Each component can focus on its core task without handling cross-cutting concerns
- **Flexible Architecture**: Easily add new features by subscribing to existing events without modifying original code
- **Control Flow**: Choose immediate or background processing based on your needs
- **Testing**: Simplified testing as components can be tested in isolation
- **Stay Reliable**: Built-in error handling and thread safety
- **Non-Blocking**: Efficient message processing with async I/O

## Installation

```sh
bundle add local_bus
```

## Quick Start

### Interfaces

- **Bus**: Single-threaded, immediate message delivery using Socketry `Async` with non-blocking I/O operations
- **Station**: Multi-threaded message queuing powered by a thread pool, processing messages through the Bus without blocking the main thread

### Bus (immediate processing)

Best for operations that should be processed as soon as possible.
(e.g. API calls required for the current operation, etc.)

```ruby
bus = LocalBus::Bus.new # ... or LocalBus.instance.bus

# register a subscriber
bus.subscribe "user.created" do |message|
  # business logic (e.g. API calls, database queries, disk operations, etc.)
end

message = bus.publish("user.created", user_id: 123)

message.wait        # blocks until all subscribers complete
message.subscribers # waits and returns the subscribers
#=> [#<LocalBus::Subscriber:0x000000012bbb79a8 ...>]
```

Subscribe with an explicit `callable`.

```ruby
callable = ->(message) do
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end
LocalBus.instance.bus.subscribe "user.created", callable: callable

message = LocalBus.instance.bus.publish("user.created", user_id: 123)
message.subscribers
#=> [#<LocalBus::Subscriber:0x0000000126b7cf38 ...>]

message.subscribers.first.value
#=> "It worked!"

# subscribe with any object that responds to #call
class UserCreatedCallable
  def call(message)
    # business logic (e.g. API calls, database queries, disk operations, etc.)
    "It worked!"
  end
end

LocalBus.instance.bus.subscribe "user.created", callable: UserCreatedCallable.new
message = LocalBus.instance.bus.publish("user.created", user_id: 123)
message.subscribers
#=> [#<LocalBus::Subscriber:0x0000000126b7cf38 ...>]

# access subscriber (callable) values
message.subscribers.first.value
#=> "It worked!"
```

### Station (background processing)

Best for operations not not immediately required for the current operation.

```ruby
station = LocalBus::Station.new # ... or LocalBus.instance.station

station.subscribe "email.welcome" do |message|
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end

message = station.publish("email.welcome", user_id: 123)

message.wait        # blocks until all subscribers complete
message.subscribers # blocks and waits until all subscribers complete and returns the subscribers
#=> [#<LocalBus::Subscriber:0x00000001253156e8 ...>]

message.subscribers.first.value
#=> "It worked!"
```

Subscribe with an explicit `callable`.

```ruby
callable = ->(message) do
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end
LocalBus.instance.station.subscribe "email.welcome", callable: callable

message = LocalBus.instance.station.publish("email.welcome", user_id: 123)
message.subscribers
#=> [#<LocalBus::Subscriber:0x0000000126b7cf38 ...>]

message.subscribers.first.value
#=> "It worked!"

# you can use any object that responds to #call
class WelcomeEmailCallable
  def call(message)
    # business logic (e.g. API calls, database queries, disk operations, etc.)
    "It worked!"
  end
end

LocalBus.instance.station.subscribe "email.welcome", callable: WelcomeEmailCallable.new
message = LocalBus.instance.station.publish("email.welcome", user_id: 123)
message.subscribers
#=> [#<LocalBus::Subscriber:0x0000000126b7cf38 ...>]

message.subscribers.first.value
#=> "It worked!"
```

## Advanced Usage & Considerations

### Concurrency Controls

#### Bus Interface

The Bus interface uses Async's Semaphore to limit resource consumption.
The configured `concurrency` limits how many operations can run at once.

```ruby
# Configure concurrency limits for the Bus (default: Etc.nprocessors)
bus = LocalBus::Bus.new(concurrency: 10)
```

> [!NOTE]
> When the max concurrency limit is reached, new publish operations will wait until a slot becomes available.
> This helps to ensure we don't over utilize system resources.

#### Station Interface

The Station interface uses a thread pool for multi-threaded message processing.

```ruby
# Configure the pool size for the Station
station = LocalBus::Station.new(
  size: 5_000, # max queued messages allowed (default: 10_000)
  threads: 10, # max number of threads (default: Etc.nprocessors)
)
```

##### Message Priority

The Station interface supports assigning a priority to each message.
Messages with a higher priority are processed before lower priority messaages.

```ruby
station = LocalBus.instance.station
station.publish("critical", priority: 10) # processed first
station.publish("important", priority: 5) # processed next
station.publish("default")                # processed last
```

### Error Handling & Recovery

Both interfaces implement error boundaries to prevent individual subscriber failures from affecting other subscribers:

```ruby
bus = LocalBus::Bus.new

bus.subscribe "user.created" do |message|
  raise "Something went wrong!"
  # never reached (business logic...)
end

bus.subscribe "user.created" do |message|
  # This still executes despite the error in the subscriber above
  # business logic (e.g. API calls, database queries, disk operations, etc.)
end

# The publish operation completes with partial success
message = bus.publish("user.created", user_id: 123)
errored_subscribers = message.subscribers.select(&:errored?)
#=> [#<LocalBus::Subscriber:0x000000011ebbcaf0 ...>]

errored_subscribers.first.error
#=> #<LocalBus::Subscriber::Error: Invocation failed! Something went wrong!>
```

### Memory Considerations

Messages are held in memory until all subscribers have completed.
Consider this when publishing large payloads or during high load scenarios.

```ruby
# memory-efficient publishing of large datasets
large_dataset.each_slice(100) do |batch|
  message = station.publish("data.process", items: batch)
  message.wait # wait before processing more messages
end
```

### Blocking Operations

The Bus interface uses non-blocking I/O but can still be blocked by CPU-intensive operations.

```ruby
# blocks the event loop
bus.subscribe "cpu.intensive" do |message|
  # CPU bound operation
end
```

### Shutdown & Cleanup

The Station delays process exit in an attempt to flush the queue and avoid dropped messages.
This delay can be configured via the `:flush_delay` option in the constructor (default: 1).

> [!IMPORTANT]
> Flushing makes a "best effort" to process all messages at exit, but it's not guaranteed.
> Factor for potential message loss when designing your system.
> For example, idempotency _(i.e. messages that can be re-published without unintended side effects)_.

### Limitations

- The Bus interface is single-threaded - long-running or CPU-bound subscribers can impact latency
- The Station interface may drop messages at process exit _(messages are not persisted between process restarts)_
- No distributed support - the message broker is limited to single process _(intra-process)_
- Large message payloads may impact memory usage, especially under high load
- No built-in retry mechanism for failed subscribers _(subscribers expose an error property, but you'll need to check and handle such errors)_

Consider these limitations when designing your system architecture.

## See Also

- [Message Bus](https://github.com/discourse/message_bus) - A reliable and robust messaging bus for Ruby and Rack
- [Wisper](https://github.com/krisleech/wisper) - A micro library providing Ruby objects with Publish-Subscribe capabilities

## Sponsors

<p align="center">
  <em>Proudly sponsored by</em>
</p>
<p align="center">
  <a href="https://www.clickfunnels.com?utm_source=hopsoft&utm_medium=open-source&utm_campaign=local_bus">
    <img src="https://images.clickfunnel.com/uploads/digital_asset/file/176632/clickfunnels-dark-logo.svg" width="575" />
  </a>
</p>
