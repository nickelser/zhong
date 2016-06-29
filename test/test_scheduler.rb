require_relative "helper"

class TestScheduler < Minitest::Test
  def setup
    Zhong.logger = test_logger
    Zhong.clear
  end

  def test_scheduler
    test_one_counter = 0
    test_two_counter = 0

    Zhong.schedule do
      every(10.seconds, "test_one") { test_one_counter += 1 }
      every(3.seconds, "test_two") { test_two_counter += 1 }
    end

    t = Thread.new { Zhong.start }
    sleep(7)
    Zhong.stop
    t.join

    assert_equal 1, test_one_counter
    assert_equal 3, test_two_counter
  end

  def test_scheduler_categories
    Zhong.schedule do
      category "cat1" do
        every(10.seconds, "cat_test_one") { nil }
      end
    end

    assert_equal 1, Zhong.jobs.size
    assert_equal "cat1.cat_test_one", Zhong.jobs.values.first.to_s
  end

  def test_scheduler_nested_category
    assert_raises RuntimeError do
      Zhong.schedule do
        category "cat1" do
          category "cat2"
        end
      end
    end
  end

  def test_scheduler_callbacks
    test_before_tick = 0
    test_after_tick = 0
    test_errors = 0
    test_before_run = 0
    test_after_run = 0

    Zhong.schedule do
      on(:before_tick) { test_before_tick += 1; true }
      on(:after_tick) { test_after_tick += 1 }
      on(:before_run) { test_before_run += 1; true }
      on(:after_run) { |_, _, ran| test_after_run += 1 if ran }
      error_handler { test_errors += 1 }

      every(1.second, "test_every_second") { nil }
      every(1.second, "break_every_second") { raise "boom" }
    end

    t = Thread.new { Zhong.start }
    sleep(3)
    Zhong.stop
    t.join

    assert_operator 2, :<=, test_before_tick
    assert_operator 4, :>=, test_before_tick
    assert_operator 2, :<=, test_after_tick
    assert_operator 4, :>=, test_after_tick
    assert_operator 6, :<=, test_before_run
    assert_operator 8, :>=, test_before_run
    assert_operator 2, :<=, test_after_run
    assert_operator 4, :>=, test_after_run
    assert_operator 2, :<=, test_errors
  end
end
