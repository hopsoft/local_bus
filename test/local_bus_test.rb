# frozen_string_literal: true

require "test_helper"

class LocalBusTest < Minitest::Test
  def test_singleton_instances
    assert_kind_of LocalBus, LocalBus.instance
    assert_kind_of LocalBus::Bus, LocalBus.instance.bus
    assert_kind_of LocalBus::Station, LocalBus.instance.station
  end

  def test_pub_sub
    LocalBus.instance.station.subscribe "test" do |message|
      "Hello World! #{message.payload[:info]}"
    end

    message = LocalBus.instance.bus.publish("test", info: "It worked!")
    assert_equal "Hello World! It worked!", message.subscribers.first.value
  end
end
