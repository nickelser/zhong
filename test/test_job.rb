require_relative "helper"

class TestJob < Minitest::Test
  def test_initialize
    job = Zhong::Job.new("test_initialize", {at: "12:00"}.merge(test_default_config))

    assert job
    assert !job.running?
    assert_equal "test_initialize", job.to_s
  end

  def test_should_run
    sleep 1

    job = Zhong::Job.new("test_should_run", {every: 1.second}.merge(test_default_config))

    assert_equal true, job.run?
  end

  def test_run
    success_counter = Queue.new
    job = Zhong::Job.new("test_run", {every: 1.second}.merge(test_default_config)) { success_counter << 1 }
    now = Time.now

    assert_equal 0, success_counter.size
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 1, success_counter.size
  end

  def test_run_at
    success_counter = Queue.new
    job = Zhong::Job.new("test_run_at", {every: 1.second, at: ["**:**"]}.merge(test_default_config)) { success_counter << 1 }
    now = Time.now

    assert_equal 0, success_counter.size
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 1, success_counter.size
  end

  def test_run_at_change
    success_counter = Queue.new
    job = Zhong::Job.new("test_run_at_change", {every: 1.second, at: ["**:**"]}.merge(test_default_config)) { success_counter << 1 }
    now = Time.now

    assert_equal 0, success_counter.size
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 1, success_counter.size

    job = Zhong::Job.new("test_run_at_change", {every: 1.second, at: ["**:**", "**:**"]}.merge(test_default_config)) { success_counter << 1 }
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 2, success_counter.size
  end

  def test_disable
    success_counter = Queue.new
    job = Zhong::Job.new("test_disable", {every: 1.second}.merge(test_default_config)) { success_counter << 1 }
    now = Time.now

    job.disable

    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal true, job.run?(now)
    assert_equal 0, success_counter.size

  end


  class MyRollbar
    @@calls = Hash.new { |h, k| h[k] = 0 }

    def self.with_my_owner(owner, &block)
      &block.call
      @calls[owner]++
    end

    def self.calls(owner)
      @@calls[owner]
    end
  end


  def test_owner


    Kernel.const_set "Rollbar", Class.new do
      @with_owner_calls = {}
      define_singleton_method :with_owner_calls do
        @with_owner_calls
      end

      define_singleton_method :with_owner do |owner|
        yield
        @with_owner_calls[:owner] ||= 0
        @with_owner_calls[:owner] += 1
      end
    end

    with_ownership_class = MyRollbar
    with_ownership_method = :with_my_owner

    with_owner_config = test_default_config.merge(
      with_ownership_class: with_ownership_class,
      with_ownership_method: with_ownership_method
    )

    success_counter = Queue.new

    job = Zhong::Job.new("test_owner", {every: 1.second, owner: :my_owner}.merge(with_owner_config)) { success_counter << 1 }
    now = Time.now

    assert_equal :my_owner, job.owner
    assert_equal 0, MyRollbar.calls(:my_owner)
    assert_equal 0, success_counter.size
    assert_equal true, job.run?(now)
    job.run(now)
    assert_equal false, job.run?(now)
    assert_equal 1, success_counter.size
    assert_equal 1, MyRollbar.calls(:my_owner)
  end
end
