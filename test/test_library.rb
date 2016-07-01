require_relative "helper"

class TestLibrary < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Zhong::VERSION
  end

  def teardown
    Zhong.stop
    sleep 1
  end

  def test_heartbeats
    Zhong.schedule { nil }
    t = Thread.new { Zhong.start }
    sleep(1)
    assert_equal true, Zhong.any_running?
    assert_in_delta Zhong.redis_time.to_f, Time.now.to_f, 0.1
    assert_in_delta Zhong.redis_time.to_f, Zhong.latest_heartbeat.to_f, 1
    Zhong.stop
    t.join
  end
end
