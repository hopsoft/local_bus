# frozen_string_literal: true

require_relative "test_helper"

class LocalBusTest < Minitest::Test
  def test_singleton_instance
    assert_kind_of LocalBus, LocalBus.instance
    assert_kind_of LocalBus::Bus, LocalBus.instance.bus
    assert_kind_of LocalBus::Station, LocalBus.instance.station
  end
end
