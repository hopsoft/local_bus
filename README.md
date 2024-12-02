[![Lines of Code](https://img.shields.io/badge/loc-341-47d299.svg)](http://blog.codinghorror.com/the-best-code-is-no-code-at-all/)
[![GEM Version](https://img.shields.io/gem/v/local_bus)](https://rubygems.org/gems/local_bus)
[![GEM Downloads](https://img.shields.io/gem/dt/local_bus)](https://rubygems.org/gems/local_bus)
[![Tests](https://github.com/hopsoft/local_bus/actions/workflows/tests.yml/badge.svg)](https://github.com/hopsoft/local_bus/actions)
[![Ruby Style](https://img.shields.io/badge/style-standard-168AFE?logo=ruby&logoColor=FE1616)](https://github.com/testdouble/standard)
[![Sponsors](https://img.shields.io/github/sponsors/hopsoft?color=eb4aaa&logo=GitHub%20Sponsors)](https://github.com/sponsors/hopsoft)
[![Twitter Follow](https://img.shields.io/twitter/url?label=%40hopsoft&style=social&url=https%3A%2F%2Ftwitter.com%2Fhopsoft)](https://twitter.com/hopsoft)

# LocalBus

### A lightweight single-process pub/sub system that enables clean, decoupled interactions.

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

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Key Benefits](#key-benefits)
    - [Performance and Efficiency](#performance-and-efficiency)
    - [Ease of Use](#ease-of-use)
    - [Decoupling and Modularity](#decoupling-and-modularity)
    - [Reliability and Safety](#reliability-and-safety)
  - [Use Cases and Examples](#use-cases-and-examples)
    - [Real-Time Notifications](#real-time-notifications)
    - [Background Processing](#background-processing)
    - [Decoupled Microservices Communication](#decoupled-microservices-communication)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Bus _(immediate processing)_](#bus-_immediate-processing_)
    - [Station _(background processing)_](#station-_background-processing_)
  - [Advanced Usage](#advanced-usage)
    - [Concurrency Controls](#concurrency-controls)
      - [Bus](#bus)
      - [Station](#station)
        - [Message Priority](#message-priority)
    - [Error Handling & Recovery](#error-handling--recovery)
    - [Memory Considerations](#memory-considerations)
    - [Blocking Operations](#blocking-operations)
    - [Shutdown & Cleanup](#shutdown--cleanup)
    - [Limitations](#limitations)
  - [Interfaces](#interfaces)
  - [Interfaces](#interfaces-1)
    - [Logging and Monitoring](#logging-and-monitoring)
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

By choosing LocalBus, developers can build robust, efficient, and maintainable applications with ease.

## Use Cases and Examples

LocalBus is versatile and can be applied to various scenarios within a Ruby application. Here are some common use cases and examples:

### Real-Time Notifications

Use LocalBus to send real-time notifications to users when specific events occur, such as user sign-ups or order completions.

```ruby
bus = LocalBus::Bus.new

# Subscribe to user sign-up events
bus.subscribe "user.signed_up" do |message|
  NotificationService.send_welcome_email(message.payload[:user_id])
end

# Publish a user sign-up event
bus.publish("user.signed_up", user_id: 123)
```

### Background Processing

Offload non-critical tasks to be processed in the background, such as sending emails or generating reports.

```ruby
station = LocalBus::Station.new

# Subscribe to report generation requests
station.subscribe "report.generate" do |message|
  ReportService.generate(message.payload[:report_id])
end

# Publish a report generation request
station.publish("report.generate", report_id: 456)
```

### Decoupled Microservices Communication

Facilitate communication between different parts of a microservices architecture without tight coupling.

```ruby
bus = LocalBus::Bus.new

# Service A publishes an event
bus.publish("order.created", order_id: 789)

# Service B subscribes to the event
bus.subscribe "order.created" do |message|
  InventoryService.update_stock(message.payload[:order_id])
end
```

## Installation

```bash
bundle add local_bus
```

## Usage

- **Bus**: Single-threaded, immediate message delivery using Socketry `Async` with non-blocking I/O operations
- **Station**: Multi-threaded message queuing powered by a thread pool, processing messages through the Bus without blocking the main thread

### Bus _(immediate processing)_

Best for work required by the current operation.

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

### Station _(background processing)_

Best for work not required by the current operation. _i.e. it can be executed later_

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

## Advanced Usage

### Concurrency Controls

#### Bus

The Bus uses Async's Semaphore to limit resource consumption.
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

```ruby
# Configure the pool size for the Station
station = LocalBus::Station.new(
  size: 5_000, # max queued messages allowed (default: 10_000)
  threads: 10, # max number of threads (default: Etc.nprocessors)
)
```

##### Message Priority

The Station supports assigning a priority to each message.
Messages with a higher priority are processed before lower priority messages.

```ruby
station = LocalBus.instance.station
station.publish("critical", priority: 10) # processed first
station.publish("important", priority: 5) # processed next
station.publish("default")                # processed last
```

### Error Handling & Recovery

Both Bus and Station implement error boundaries to prevent individual subscriber failures from affecting other subscribers:

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

The Bus uses non-blocking I/O but can still be blocked by CPU-intensive operations.

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
> For example, idempotency _i.e. messages that can be re-published without unintended side effects_.

### Limitations

- The Bus is single-threaded - long-running or CPU-bound subscribers can impact latency
- The Station may drop messages at process exit _(messages are not persisted between process restarts)_
- No distributed support - the message broker is limited to single process _(intra-process)_
- Large message payloads may impact memory usage, especially under high load
- No built-in retry mechanism for failed subscribers _(subscribers expose an error property, but you'll need to check and handle such errors)_

Consider these limitations when designing your system architecture.

## Interfaces

## Interfaces

<details>
<summary>Bus</summary>

| Method            | Arguments                                                                           | Return Type                     | Description                                                         |
|-------------------|-------------------------------------------------------------------------------------|---------------------------------|---------------------------------------------------------------------|
| `initialize`      | `:concurrency` => `Etc.nprocessors`                                                 | `Bus`                           | Creates a new Bus instance with specified max concurrency           |
| `concurrency`     |                                                                                     | `Integer`                       | Returns the maximum number of concurrent tasks                      |
| `concurrency=`    | `value`                                                                             | `Integer`                       | Sets the max concurrency                                            |
| `topics`          |                                                                                     | `Array[String]`                 | Returns array of registered topic names                             |
| `subscriptions`   |                                                                                     | `Hash[String, Array[callable]]` | Returns hash mapping topics to their subscribers                    |
| `subscribe`       | `topic`, `:callable: (Message) -> untyped` => `nil`, `&block: (Message) -> untyped` | `self`                          | Subscribes a callable to a topic. Provide either callable or block. |
| `unsubscribe`     | `topic`, `:callable: (Message) -> untyped`                                          | `self`                          | Unsubscribes a callable from a topic                                |
| `unsubscribe_all` | `topic`                                                                             | `self`                          | Removes all subscribers from a topic                                |
| `with_topic`      | `topic`, `&block: (String) -> void`                                                 | `void`                          | Executes block and unsubscribes all from topic afterwards           |
| `publish`         | `topic`, `:timeout: Float` => `60`, `**payload: Hash`                               | `Message`                       | Publishes message to topic with optional timeout and payload        |
| `publish_message` | `message`, `:priority` => `1`                                                       | `Message`                       | Publishes a pre-constructed Message object to queue                 |

</details>

<details>
<summary>Station</summary>

| Method            | Arguments                                                                           | Return Type | Description                                                         |
|-------------------|-------------------------------------------------------------------------------------| ------------|---------------------------------------------------------------------|
| `initialize`      | `:bus` => `Bus.new`, `:interval` => `0.01`, `:size` => `10_000`,                    | `void`      | Creates a new Station instance with specified configuration         |
|                   | `:threads` => `Etc.nprocessors`, `:timeout` => `60`, `:flush_delay` => `1`          |             |                                                                     |
| `bus`             |                                                                                     | `Bus`       | Returns the Bus instance                                            |
| `interval`        |                                                                                     | `Float`     | Returns queue polling interval in seconds                           |
| `size`            |                                                                                     | `Integer`   | Returns max queue size                                              |
| `threads`         |                                                                                     | `Integer`   | Returns number of threads in use                                    |
| `timeout`         |                                                                                     | `Float`     | Returns default timeout for message processing                      |
| `start`           | `:interval` => `self.interval`, `:threads` => `self.threads`                        | `void`      | Starts the station                                                  |
| `stop`            | `:timeout` => `nil`                                                                 | `void`      | Stops the station                                                   |
| `running?`        |                                                                                     | `bool`      | Indicates if the station is running                                 |
| `pending`         |                                                                                     | `Integer`   | Returns number of pending unprocessed messages                      |
| `subscribe`       | `topic`, `:callable` => `nil`, `&block`                                             | `self`      | Subscribes a callable to a topic. Provide either callable or block. |
| `unsubscribe`     | `topic`                                                                             | `self`      | Unsubscribes from a topic                                           |
| `unsubscribe_all` | `topic`                                                                             | `self`      | Removes all subscribers from a topic                                |
| `publish`         | `topic`, `:priority` => `1`, `:timeout` => `self.timeout`, `**payload`              | `Message`   | Publishes message to queue with optional priority and timeout       |
| `publish_message` | `message`, `:priority` => `1`                                                       | `Message`   | Publishes a pre-constructed Message object to queue                 |

</details>

<details>
<summary>Message</summary>

| Method        | Arguments                                 | Return Type             | Description                                                     |
| ------------- | ----------------------------------------- | ----------------------- | --------------------------------------------------------------- |
| `initialize`  | `topic`, `:timeout` => `nil`, `**payload` | `Message`               | Creates a new Message instance with the given topic and payload |
| `metadata`    |                                           | `Hash[Symbol, untyped]` | Returns message metadata                                        |
| `id`          |                                           | `String`                | Returns unique identifier for the message                       |
| `topic`       |                                           | `String`                | Returns message topic                                           |
| `payload`     |                                           | `Hash`                  | Returns message payload                                         |
| `created_at`  |                                           | `Time`                  | Returns time when message was created                           |
| `thread_id`   |                                           | `Integer`               | Returns ID of thread that created the message                   |
| `timeout`     |                                           | `Float`                 | Returns timeout for message processing in seconds               |
| `wait`        | `:interval` => `0.1`                      | `void`                  | Blocks and waits for message to process                         |
| `subscribers` |                                           | `Array[Subscriber]`     | Returns all subscribers after waiting for processing            |
| `to_h`        |                                           | `Hash[Symbol, untyped]` | Converts message to a hash (alias for metadata)                 |

</details>


<details>
<summary>Subscriber</summary>

| Method            | Arguments             | Return Type               | Description                                                         |
| ----------------- | --------------------- | ------------------------- | ------------------------------------------------------------------- |
| `initialize`      | `callable`, `message` | `Subscriber`              | Creates a new Subscriber instance with a callable and message       |
| `id`              |                       | `Integer`                 | Returns unique identifier for the subscriber                        |
| `source_location` |                       | `Array[String, Integer]?` | Returns file and line number where callable was defined             |
| `callable`        |                       | `#call`                   | Returns the callable object (Proc, lambda, etc.)                    |
| `error`           |                       | `Error?`                  | Returns error if subscriber failed (after performing)               |
| `message`         |                       | `Message`                 | Returns message for the subscriber to process                       |
| `metadata`        |                       | `Hash[Symbol, untyped]`   | Returns metadata including timing, thread info, and message details |
| `value`           |                       | `untyped`                 | Returns value returned by the callable (after performing)           |
| `performed?`      |                       | `bool`                    | Indicates if the subscriber has been performed                      |
| `pending?`        |                       | `bool`                    | Indicates if the subscriber is pending/unperformed                  |
| `errored?`        |                       | `bool`                    | Indicates if the subscriber has errored                             |
| `perform`         |                       | `void`                    | Performs the subscriber's callable                                  |
| `timeout`         | `cause`               | `void`                    | Marks subscriber as timed out with given cause                      |
| `to_h`            |                       | `Hash[Symbol, untyped]`   | Returns the subscriber's data as a hash                             |

</details>

### Logging and Monitoring

Implement a centralized logging system where different components can log messages to a single location.

```ruby
bus = LocalBus::Bus.new

# Subscribe to log events
bus.subscribe "log.info" do |message|
  LoggerService.log_info(message.payload[:message])
end

# Publish a log event
bus.publish("log.info", message: "User logged in")
```

These examples demonstrate how LocalBus can be used to build efficient, decoupled, and maintainable applications. By leveraging LocalBus, developers can streamline communication between components and improve the overall architecture of their systems.

## See Also

- [Message Bus](https://github.com/discourse/message_bus) - A reliable and robust messaging bus for Ruby and Rack
- [Wisper](https://github.com/krisleech/wisper) - A micro library providing Ruby objects with Publish-Subscribe capabilities
