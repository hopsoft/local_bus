<p align="center">
  <a href="http://blog.codinghorror.com/the-best-code-is-no-code-at-all/">
    <img alt="Lines of Code" src="https://img.shields.io/badge/loc-328-47d299.svg" />
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

LocalBus is a pub/sub system for Ruby applications that helps organize intra-process communication. It provides a clean way to decouple components and manage event-driven behavior within a single process through two interfaces:

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
      - [Bus Interface (Async)](#bus-interface-async)
      - [Station Interface (Thread Pool)](#station-interface-thread-pool)
    - [Error Handling & Recovery](#error-handling--recovery)
    - [Memory Considerations](#memory-considerations)
    - [Blocking Operations](#blocking-operations)
    - [Shutdown & Cleanup](#shutdown--cleanup)
    - [Limitations](#limitations)
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

- **Bus**: Single-threaded, immediate message delivery using Socketry Async with non-blocking I/O operations
- **Station**: Multi-threaded message queuing powered by Concurrent Ruby's thread pool, processing messages through the Bus without blocking the main thread

Both interfaces ensure optimal performance:

- Bus leverages async I/O to prevent blocking on network or disk operations
- Station offloads work to a managed thread pool, keeping the main thread responsive
- Both interfaces support an explicit `wait` for subscribers

### Bus (immediate processing)

Best for real-time operations like logging, metrics, and state updates.

```ruby
bus = LocalBus.instance.bus

bus.subscribe "user.created" do |message|
  AuditLog.record(message.payload)
  true
end

# publish returns a promise-like object that resolves to subscribers
result = bus.publish("user.created", user_id: 123)
result.wait  # Blocks until all subscribers complete
result.value # blocks and waits until all subscribers complete and returns the subscribers
```

### Station (background processing)

Best for async operations like emails, notifications, and resource-intensive tasks.

```ruby
station = LocalBus::Station.new # ... or LocalBus.instance.station

station.subscribe "email.welcome" do |message|
  WelcomeMailer.deliver(message.payload[:user_id])
  true
end

# Returns a Promise or Future that resolves to subscribers
result = station.publish("email.welcome", user_id: 123)
result.wait  # Blocks until all subscribers complete
result.value # blocks and waits until all subscribers complete and returns the subscribers
```

## Advanced Usage & Considerations

### Concurrency Controls

#### Bus Interface (Async)

The Bus interface uses Async's Semaphore to limit resource consumption:

```ruby
# Configure concurrency limits for the Bus
bus = LocalBus::Bus.new(concurrency_limit: 10)

# The semaphore ensures only N concurrent operations run at once
bus.subscribe "resource.intensive" do |message|
  # Only 10 of these will run concurrently
  perform_intensive_operation(message)
end
```

When the concurrency limit is reached, new publish operations will wait until a slot becomes available. This prevents memory bloat but means you should be mindful of timeouts in your subscribers.

#### Station Interface (Thread Pool)

The Station interface uses Concurrent Ruby's fixed thread pool with a fallback policy:

```ruby
# Configure the thread pool size for the Station
station = LocalBus::Station.new(
  max_queue: 5_000, # Maximum number of queued items
  threads: 10, # Maximum pool size
  fallback_policy: :caller_runs # Runs on calling thread
)
```

The fallback policy determines behavior when the thread pool is saturated:

- `:caller_runs` - Executes the task in the publishing thread (can block)
- `:abort` - Raises an error
- `:discard` - Silently drops the task

### Error Handling & Recovery

Both interfaces implement error boundaries to prevent individual subscriber failures from affecting others:

```ruby
bus.subscribe "user.created" do |message|
  raise "Something went wrong!"
  true # Never reached
end

bus.subscribe "user.created" do |message|
  # This still executes despite the error above
  notify_admin(message)
  true
end

# The publish operation completes with partial success
result = bus.publish("user.created", user_id: 123)
result.wait
errored_subscribers = result.value.select(&:error)
```

### Memory Considerations

Messages are held in memory until all subscribers complete processing. For the Station interface, this includes time spent in the thread pool queue. Consider this when publishing large payloads or during high load:

```ruby
# Memory-efficient publishing of large datasets
large_dataset.each_slice(100) do |batch|
  station.publish("data.process", items: batch).wait
end
```

### Blocking Operations

The Bus interface uses non-blocking I/O but can still be blocked by CPU-intensive operations:

```ruby
# Bad - blocks the event loop
bus.subscribe "cpu.intensive" do |message|
  perform_heavy_calculation(message)
end

# Better - offload to Station for CPU-intensive work
station.subscribe "cpu.intensive" do |message|
  perform_heavy_calculation(message)
end
```

### Shutdown & Cleanup

LocalBus does its best to handle graceful shutdown when the process exits, and works to ensure published messages are processed.
However, it's possible that some messages may be lost when the process exits.

Factor for potential message loss when designing your system.
For example, idempotency _(i.e. messages that can be re-published without unintended side effects)_.

### Limitations

- The Bus interface is single-threaded - long-running subscribers can impact latency
- The Station interface may drop messages if configured with `:discard` fallback policy
- No persistence - pending messages are lost on process restart
- No distributed support - communication limited to single process
- Large payloads can impact memory usage, especially under high load
- No built-in retry mechanism for failed subscribers

Consider these limitations when designing your system architecture.

## Sponsors

<p align="center">
  <em>Proudly sponsored by</em>
</p>
<p align="center">
  <a href="https://www.clickfunnels.com?utm_source=hopsoft&utm_medium=open-source&utm_campaign=local_bus">
    <img src="https://images.clickfunnel.com/uploads/digital_asset/file/176632/clickfunnels-dark-logo.svg" width="575" />
  </a>
</p>
