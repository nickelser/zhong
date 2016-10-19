require_relative "helper"

class TestLibrary < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Zhong::VERSION
  end

  def teardown
    Zhong.stop
    sleep 1
  end

  def test_logger
    test_logger = Zhong.logger
    Zhong.logger = nil
    assert_output(nil, nil) { Zhong.logger.info "ensure has default logger" }
    Zhong.logger = test_logger
  end

  def test_heartbeats
    Zhong.schedule { nil }
    t = Thread.new { Zhong.start }
    sleep(1)
    assert_equal true, Zhong.any_running?
    assert_in_delta Zhong.redis_time.to_f, Time.now.to_f, 1
    assert_in_delta Zhong.redis_time.to_f, Zhong.latest_heartbeat.to_f, 1
    refute_empty Zhong.all_heartbeats
    Zhong.stop
    t.join
  end

  def test_redis_change
    Zhong.schedule { nil }
    t = Thread.new { Zhong.start }
    sleep(1)
    assert_equal true, Zhong.any_running?
    test_redis = Zhong.redis
    Zhong.stop
    t.join
    Zhong.redis = Redis.new(url: "redis://localhost/15")
    refute Zhong.any_running?(5.seconds)
    t = Thread.new { Zhong.start }
    sleep(1)
    assert_equal true, Zhong.any_running?
    assert_in_delta Zhong.redis_time.to_f, Time.now.to_f, 1
    Zhong.stop
    Zhong.redis = test_redis
    t.join
  end
end
