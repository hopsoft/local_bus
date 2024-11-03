<p align="center">
  <a href="http://blog.codinghorror.com/the-best-code-is-no-code-at-all/">
    <img alt="Lines of Code" src="https://img.shields.io/badge/loc-1050-47d299.svg" />
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

- **Bus**: Single-threaded, immediate message delivery
- **Station**: Multi-threaded message queuing that processes messages through the Bus

## Why LocalBus?

- **Decouple Components**: Break complex systems into maintainable parts
- **Control Flow**: Choose immediate or background processing
- **Stay Reliable**: Built-in error handling and thread safety
- **Non-Blocking**: Efficient message processing with async I/O

## Installation

```sh
bundle add local_bus
```

## Usage

### Bus (Immediate Processing)
Best for real-time operations like logging, metrics, and state updates.

```ruby
bus = LocalBus.instance.bus

bus.subscribe "user.created" do |message|
  AuditLog.record(message.payload)
  true
end

# Returns a Monitor that tracks subscriber completion
monitor = bus.publish("user.created", user_id: 123)
monitor.wait  # Blocks until all subscribers complete
subscribers = monitor.value  # Safe to access after wait
```

### Station (Background Processing)
Best for async operations like emails, notifications, and resource-intensive tasks.

```ruby
station = LocalBus.instance.station

station.subscribe "email.welcome" do |message|
  WelcomeMailer.deliver(message.payload[:user_id])
  true
end

# Returns a Future that resolves to subscriber results
future = station.publish("email.welcome", user_id: 123)
future.wait  # Blocks until all subscribers complete
subscribers = future.value  # Safe to access after wait
```

## Advanced Usage

```ruby
# Both Bus and Station support the same waiting pattern
results = bus.publish("event", data: "value")
  .wait     # Block until complete
  .value    # Get the subscribers
  .map(&:value)  # Get the return values

# Check subscriber results
subscribers = station.publish("event", data: "value").wait.value
subscribers.each do |subscriber|
  if subscriber.error
    puts "Error: #{subscriber.error.message}"
  else
    puts "Success: #{subscriber.value}"
  end
end
```

## Sponsors

<p align="center">
  <em>Proudly sponsored by</em>
</p>
<p align="center">
  <a href="https://www.clickfunnels.com?utm_source=hopsoft&utm_medium=open-source&utm_campaign=local_bus">
    <img src="https://images.clickfunnel.com/uploads/digital_asset/file/176632/clickfunnels-dark-logo.svg" width="575" />
  </a>
</p>
