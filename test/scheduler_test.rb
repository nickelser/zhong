require "test_helper"

class TestScheduler < Minitest::Test
  def test_scheduler
    test_one_counter = 0
    test_two_counter = 0

    Zhong.schedule do
      every(10.seconds, "test_one") { test_one_counter += 1 }
      every(3.seconds, "test_two") { test_two_counter += 1 }
    end

    Thread.new { Zhong.start }
    sleep(6)
    Zhong.stop
    assert_equal 1, test_one_counter
    assert_equal 3, test_two_counter
  end
end
