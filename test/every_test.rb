require "test_helper"

class TestEvery < Minitest::Test
  def time_in_day(hour, minute, day = 0, sec = 0)
    Time.new.change(hour: hour, min: minute, sec: sec) + day.days
  end

  def test_numeric_every_10s
    every = Zhong::Every.parse(10)

    assert_equal time_in_day(16, 20, 0, 10), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 0, 20), every.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20, 0, 25), every.next_at(time_in_day(16, 20, 0, 15))
    assert_equal time_in_day(0, 0, 1, 9), every.next_at(time_in_day(23, 59, 0, 59))
  end

  def test_numeric_every_30s
    every = Zhong::Every.parse(30)

    assert_equal time_in_day(16, 20, 0, 30), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 0, 40), every.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20, 0, 45), every.next_at(time_in_day(16, 20, 0, 15))
    assert_equal time_in_day(0, 0, 1, 29), every.next_at(time_in_day(23, 59, 0, 59))
  end

  def test_duration_30s
    every = Zhong::Every.parse(30.seconds)

    assert_equal time_in_day(16, 20, 0, 30), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 0, 40), every.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20, 0, 45), every.next_at(time_in_day(16, 20, 0, 15))
    assert_equal time_in_day(0, 0, 1, 29), every.next_at(time_in_day(23, 59, 0, 59))
  end

  def test_duration_1s
    every = Zhong::Every.parse(1.second)

    assert_equal time_in_day(16, 20, 0, 1), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 0, 11), every.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20, 0, 16), every.next_at(time_in_day(16, 20, 0, 15))
    assert_equal time_in_day(0, 0, 1, 0), every.next_at(time_in_day(23, 59, 0, 59))
  end

  def test_duration_3_weeks
    every = Zhong::Every.parse(3.weeks)

    assert_equal time_in_day(16, 20, 21), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 21, 10), every.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20, 21, 15), every.next_at(time_in_day(16, 20, 0, 15))
    assert_equal time_in_day(0, 0, 21, 10), every.next_at(time_in_day(0, 0, 0, 10))
  end

  def test_symbol_day
    every = Zhong::Every.parse(:day)

    assert_equal time_in_day(16, 20, 1, 0), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 1, 40), every.next_at(time_in_day(16, 20, 0, 40))
    assert_equal time_in_day(16, 20, 1, 45), every.next_at(time_in_day(16, 20, 0, 45))
    assert_equal time_in_day(0, 0, 1, 10), every.next_at(time_in_day(0, 0, 0, 10))
  end

  def test_string_day
    every = Zhong::Every.parse("day")

    assert_equal time_in_day(16, 20, 1, 0), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 1, 40), every.next_at(time_in_day(16, 20, 0, 40))
    assert_equal time_in_day(16, 20, 1, 45), every.next_at(time_in_day(16, 20, 0, 45))
    assert_equal time_in_day(0, 0, 1, 10), every.next_at(time_in_day(0, 0, 0, 10))
  end

  def test_string_week
    every = Zhong::Every.parse("week")

    assert_equal time_in_day(16, 20, 7, 0), every.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20, 7, 40), every.next_at(time_in_day(16, 20, 0, 40))
    assert_equal time_in_day(16, 20, 7, 45), every.next_at(time_in_day(16, 20, 0, 45))
    assert_equal time_in_day(0, 0, 7, 10), every.next_at(time_in_day(0, 0, 0, 10))
  end

  def test_invalid_string_foo
    assert_raises Zhong::Every::FailedToParse do
      Zhong::Every.parse("foo")
    end
  end

  def test_invalid_object
    assert_raises Zhong::Every::FailedToParse do
      Zhong::Every.parse(true)
    end
  end

  def test_nil_argument
    assert_raises Zhong::Every::FailedToParse do
      Zhong::Every.parse(nil)
    end
  end

  def test_invalid_blank
    assert_raises Zhong::Every::FailedToParse do
      Zhong::Every.parse("")
    end
  end
end
