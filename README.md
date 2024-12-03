[![Lines of Code](https://img.shields.io/badge/loc-364-47d299.svg)](http://blog.codinghorror.com/the-best-code-is-no-code-at-all/)
[![GEM Version](https://img.shields.io/gem/v/local_bus)](https://rubygems.org/gems/local_bus)
[![GEM Downloads](https://img.shields.io/gem/dt/local_bus)](https://rubygems.org/gems/local_bus)
[![Tests](https://github.com/hopsoft/local_bus/actions/workflows/tests.yml/badge.svg)](https://github.com/hopsoft/local_bus/actions)
[![Ruby Style](https://img.shields.io/badge/style-standard-168AFE?logo=ruby&logoColor=FE1616)](https://github.com/testdouble/standard)
[![Sponsors](https://img.shields.io/github/sponsors/hopsoft?color=eb4aaa&logo=GitHub%20Sponsors)](https://github.com/sponsors/hopsoft)
[![Twitter Follow](https://img.shields.io/twitter/url?label=%40hopsoft&style=social&url=https%3A%2F%2Ftwitter.com%2Fhopsoft)](https://twitter.com/hopsoft)

# LocalBus

### A lightweight single-process pub/sub system that enables clean, decoupled interactions.

> [!TIP]
> At under 400 lines of code. The LocalBus source can be reviewed quickly to grok its implementation and internals.

## Why LocalBus?

A message bus (or enterprise service bus) is an architectural pattern that enables different parts of an application to communicate without direct knowledge of each other.
Think of it as a smart postal service for your application - components can send messages to topics, and other components can listen for those messages, all without knowing about each other directly.

Even within a single process, this pattern offers powerful benefits:

- **Decouple Components**: Break complex systems into maintainable parts that can evolve independently
- **Single Responsibility**: Each component can focus on its core task without handling cross-cutting concerns
- **Flexible Architecture**: Easily add new features by subscribing to existing events without modifying original code
- **Control Flow**: Choose immediate or background processing based on your needs
- **Testing**: Simplified testing as components can be tested in isolation
- **Stay Reliable**: Built-in error handling and thread safety
- **Non-Blocking**: Efficient message processing with async I/O

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Key Benefits](#key-benefits)
    - [Performance and Efficiency](#performance-and-efficiency)
    - [Ease of Use](#ease-of-use)
    - [Decoupling and Modularity](#decoupling-and-modularity)
    - [Reliability and Safety](#reliability-and-safety)
  - [Use Cases](#use-cases)
  - [Key Components](#key-components)
    - [Bus](#bus)
    - [Station](#station)
    - [LocalBus](#localbus)
  - [Installation](#installation)
    - [Requirements](#requirements)
  - [Usage](#usage)
    - [LocalBus](#localbus-1)
    - [Bus](#bus-1)
    - [Station](#station-1)
  - [Advanced Usage](#advanced-usage)
    - [Concurrency Controls](#concurrency-controls)
      - [Bus](#bus-2)
      - [Station](#station-2)
        - [Message Priority](#message-priority)
    - [Error Handling](#error-handling)
    - [Memory Considerations](#memory-considerations)
    - [Blocking Operations](#blocking-operations)
    - [Shutdown & Cleanup](#shutdown--cleanup)
    - [Limitations](#limitations)
    - [Demos & Benchmarks](#demos--benchmarks)
  - [See Also](#see-also)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Key Benefits

LocalBus offers several advantages that make it an attractive choice for Ruby developers looking to implement a pub/sub system within a single process:

### Performance and Efficiency

- **Non-Blocking I/O:** Leveraging the power of the `Async` library, LocalBus ensures efficient message processing without blocking the main thread, leading to improved performance in I/O-bound applications.
- **Optimized Resource Usage:** By using semaphores and thread pools, LocalBus efficiently manages system resources, allowing for high concurrency without overwhelming the system.

### Ease of Use

- **Simple Setup:** With straightforward installation and intuitive API, LocalBus allows developers to quickly integrate pub/sub capabilities into their applications.
- **Minimal Configuration:** Default settings are optimized for most use cases, reducing the need for complex configurations.

### Decoupling and Modularity

- **Component Isolation:** LocalBus enables clean separation of concerns by allowing components to communicate through messages without direct dependencies or tight coupling.
- **Scalable Architecture:** Easily extend your application by adding new subscribers to existing topics, facilitating the addition of new features without modifying existing code.

### Reliability and Safety

- **Built-in Error Handling:** LocalBus includes error boundaries to ensure that failures in one subscriber do not affect others, maintaining system stability.
- **Thread Safety:** Designed with concurrency in mind, LocalBus provides thread-safe operations to prevent race conditions and ensure data integrity.

## Use Cases

LocalBus is versatile and can be applied to various scenarios within a Ruby application. Here are some common use cases and examples:

<details>
<summary><b>Decoupled Communication</b></summary>
<br>
Facilitate communication between different parts of a component-based architecture without tight coupling.

```ruby
# Component A subscribes to order creation events
LocalBus.subscribe "order.created" do |message|
  InventoryService.update_stock message.payload[:order_id]
end

# Component B publishes an order creation event
LocalBus.publish "order.created", order_id: 789
```

</details>

<details>
<summary><b>Real-Time Notifications</b></summary>
<br>
Use LocalBus to send real-time notifications to users when specific events occur, such as user sign-ups or order completions.

```ruby
# Subscribe to user sign-up events
LocalBus.subscribe "user.signed_up" do |message|
  NotificationService.send_welcome_email message.payload[:user_id]
end

# Publish a user sign-up event
LocalBus.publish "user.signed_up", user_id: 123
```

</details>

<details>
<summary><b>Background Processing</b></summary>
<br>
Offload non-critical tasks to be processed in the background, such as sending emails or generating reports.

```ruby
# Subscribe to report generation requests
LocalBus.subscribe "report.generate" do |message|
  ReportService.generate message.payload[:report_id]
end

# Publish a report generation request
LocalBus.publish "report.generate", report_id: 456
```

</details>

## Key Components

### Bus

The Bus acts as a direct transport mechanism for messages, akin to placing a passenger directly onto a bus.
When a message is published to the Bus, it is immediately delivered to all subscribers, ensuring prompt execution of tasks.
This is achieved through non-blocking I/O operations, which allow the Bus to handle multiple tasks efficiently without blocking the main thread.

> [!NOTE]
> While the Bus uses asynchronous operations to optimize performance,
> the actual processing of a message may still experience slight delays due to I/O wait times from prior messages.
> This means that while the Bus aims for immediate processing, the nature of asynchronous operations can introduce some latency.

### Station

The Station serves as a queuing system for messages, similar to a bus station where passengers wait for their bus.

When a message is published to the Station, it is queued and processed at a later time, allowing for deferred execution.
This is particularly useful for tasks that can be handled later.

The Station employs a thread pool to manage message processing, enabling high concurrency and efficient resource utilization.
Messages can also be prioritized, ensuring that higher-priority tasks are processed first.

> [!NOTE]
> While the Station provides a robust mechanism for background processing,
> it's important to understand that the exact timing of message processing is not controlled by the publisher,
> and messages will be processed as resources become available.

### LocalBus

The LocalBus class serves as the primary interface to the library, providing a convenient singleton pattern for accessing both Bus and Station functionality.
It exposes singleton instances of both Bus and Station providing a simplified API for common pub/sub operations.

By default, LocalBus delegates to the Station singleton for all pub/sub operations, making it ideal for background processing scenarios.
This means that when you use `LocalBus.publish` or `LocalBus.subscribe`, you're actually working with default Station, benefiting from its queuing and thread pool capabilities.

## Installation

```bash
bundle add local_bus
```

### Requirements

- Ruby `>= 3.0`

## Usage

### LocalBus

```ruby
LocalBus.subscribe "user.created" do |message|
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end

message = LocalBus.publish("user.created", user_id: 123)
message.wait        # blocks until all subscribers complete
message.subscribers # blocks and waits until all subscribers complete and returns the subscribers
#=> [#<LocalBus::Subscriber:0x0000000120f75c30 ...>]

message.subscribers.first.value
#=> "It worked!"
```

### Bus

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

# subscribe with any object that responds to `#call`.
worker = ->(message) do
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end
bus.subscribe "user.created", callable: worker
```

### Station

```ruby
station = LocalBus::Station.new # ... or LocalBus.instance.station

station.subscribe "user.created" do |message|
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end

message = station.publish("user.created", user_id: 123)
message.wait        # blocks until all subscribers complete
message.subscribers # blocks and waits until all subscribers complete and returns the subscribers
#=> [#<LocalBus::Subscriber:0x00000001253156e8 ...>]

message.subscribers.first.value
#=> "It worked!"

# subscribe with any object that responds to `#call`.
worker = ->(message) do
  # business logic (e.g. API calls, database queries, disk operations, etc.)
  "It worked!"
end
station.subscribe "user.created", callable: worker
```

## Advanced Usage

### Concurrency Controls

#### Bus

The Bus leverages Async's Semaphore to limit resource consumption.
The configured `concurrency` limits how many operations can run at once.

```ruby
# Configure concurrency limits for the Bus (default: Etc.nprocessors)
bus = LocalBus::Bus.new(concurrency: 10)
```

> [!NOTE]
> When the max concurrency limit is reached, new publish operations will wait until a slot becomes available.
> This helps to ensure we don't over utilize system resources.

#### Station

The Station uses a thread pool for multi-threaded message processing.
You can configure the queue size and the number of threads used to process messages.

```ruby
# Configure the Station
station = LocalBus::Station.new(
  limit: 5_000, # max number of pending messages (default: 10_000)
  threads: 10,  # max number of processing threads (default: Etc.nprocessors)
)
```

##### Message Priority

The Station supports assigning a priority to each message.
Messages with a higher priority are processed before lower priority messages.

```ruby
LocalBus.publish("default")                # 3rd to process
LocalBus.publish("important", priority: 5) # 2nd to process
LocalBus.publish("critical", priority: 10) # 1st to process
```

### Error Handling

Error boundaries prevent individual subscriber failures from affecting other subscribers.

```ruby
LocalBus.subscribe "user.created" do |message|
  raise "Something went wrong!"
  # never reached (business logic...)
end

LocalBus.subscribe "user.created" do |message|
  # This still executes even though the other subscriber has an error
  # business logic (e.g. API calls, database queries, disk operations, etc.)
end

# The publish operation completes with partial success
message = LocalBus.publish("user.created", user_id: 123)
errored_subscribers = message.subscribers.select(&:errored?)
#=> [#<LocalBus::Subscriber:0x000000011ebbcaf0 ...>]

errored_subscribers.first.error
#=> #<LocalBus::Subscriber::Error: Invocation failed! Something went wrong!>
```

> [!IMPORTANT]
> It's up to you to check message subscribers and handle errors appropriately.

### Memory Considerations

Messages are held in memory until all subscribers have completed.
Consider this when publishing large payloads or during high load scenarios.

```ruby
# memory-efficient publishing of large datasets
large_dataset.each_slice(100) do |batch|
  message = LocalBus.publish("data.process", items: batch)
  message.wait # wait before processing more messages
end
```

### Blocking Operations

LocalBus facilitates non-blocking I/O but bottlenecks can still be triggered by CPU-intensive operations.

```ruby
LocalBus.subscribe "cpu.intensive" do |message|
  # CPU bound operation can trigger a bottleneck
end
```

### Shutdown & Cleanup

The Station delays process exit in an attempt to flush the queue and avoid dropped messages.
This delay can be configured via the `:wait` option in the constructor (default: 5).

> [!IMPORTANT]
> This wait time allows for processing pending messages at exit, but is not guaranteed.
> Factor for potential message loss when designing your system.
> For example, idempotency _i.e. messages that can be re-published without unintended side effects_.

### Limitations

- The Bus is single-threaded - long-running or CPU-bound subscribers can impact latency
- The Station may drop messages at process exit _(messages are not persisted between process restarts)_
- No distributed support - limited to single process _(intra-process)_
- Large message payloads may impact memory usage, especially under high load
- No built-in retry mechanism for failed subscribers _(subscribers expose an error property, but you'll need to check and handle such errors)_

Consider these limitations when designing your system architecture.

### Demos & Benchmarks

The project includes demo scripts that showcase concurrent processing capabilities:

```bash
bin/demo-bus     # demonstrates Bus performance
bin/demo-station # demonstrates Station performance
```

Both demos simulate I/O-bound operations _(1 second latency per subscriber)_ to show how LocalBus handles concurrent processing. For example, on an 10-core system:

- The Bus processes a message with 10 I/O-bound subscribers in ~1 second instead of 10 seconds
- The Station processes 10 messages with 10 I/O-bound subscribers each in ~1 second instead of 100 seconds

This demonstrates how LocalBus offers high throughput for I/O-bound operations. :raised_hands:

## See Also

- [Message Bus](https://github.com/discourse/message_bus) - A reliable and robust messaging bus for Ruby and Rack
- [Wisper](https://github.com/krisleech/wisper) - A micro library providing Ruby objects with Publish-Subscribe capabilities
