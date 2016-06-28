require "test_helper"

class TestJob < Minitest::Test
  def default_config
    @default_config ||= {
      redis: Redis.new,
      logger: logger,
      long_running_timeout: 5.minutes
    }
  end

  def logger
    @logger ||= begin
      l = Logger.new(STDOUT)
      l.level = Logger::UNKNOWN
      l
    end
  end

  def test_initialize
    job = Zhong::Job.new("test_initialize", {at: "12:00"}.merge(default_config))

    assert job
    assert !job.running?
    assert_equal "test_initialize", job.to_s
  end

  def test_should_run
    sleep 1

    job = Zhong::Job.new("test_should_run", {every: 1.second}.merge(default_config))

    assert_equal true, job.run?
  end

  def test_run
    success_counter = Queue.new
    job = Zhong::Job.new("test_run", {every: 1.second}.merge(default_config)) { success_counter << 1 }
    now = Time.now

    assert_equal 0, success_counter.size
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 1, success_counter.size
  end

  def test_disable
    success_counter = Queue.new
    job = Zhong::Job.new("test_disable", {every: 1.second}.merge(default_config)) { success_counter << 1 }
    now = Time.now

    job.disable

    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal true, job.run?(now)
    assert_equal 0, success_counter.size
  end
end
