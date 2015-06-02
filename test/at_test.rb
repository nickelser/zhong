require "test_helper"

# Many At tests lifted from Clockwork (thanks Clockwork!)
class TestAt < Minitest::Test
  def time_in_day(hour, minute, day = 0, sec = 0)
    Time.new.beginning_of_week(:monday).change(hour: hour, min: minute, sec: sec) + day.days
  end

  def test_16_20
    at = Zhong::At.parse("16:20", grace: 0)

    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 15))
    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 20))
    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 20, 0, 10))
    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 20, 0, 59))
    assert_equal time_in_day(16, 20, 1), at.next_at(time_in_day(16, 21))
    assert_equal time_in_day(16, 20, 1), at.next_at(time_in_day(16, 21, 0, 01))
    assert_equal time_in_day(16, 20, 2), at.next_at(time_in_day(16, 21, 1, 30))
  end

  def test_16_20_with_grace
    at = Zhong::At.parse("16:20", grace: 5.minutes)

    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 21))
    assert_equal time_in_day(16, 20), at.next_at(time_in_day(16, 25))
    assert_equal time_in_day(16, 20, 1), at.next_at(time_in_day(16, 26))
  end

  def test_8_20_before
    at = Zhong::At.parse("8:20")

    assert_equal time_in_day(8, 20), at.next_at(time_in_day(8, 15))
    assert_equal time_in_day(8, 20, 1), at.next_at(time_in_day(8, 21))
  end

  def test_two_star_20
    at = Zhong::At.parse("**:20")

    assert_equal time_in_day(8, 20), at.next_at(time_in_day(8, 15))
    assert_equal time_in_day(9, 20), at.next_at(time_in_day(9, 15))
    assert_equal time_in_day(10, 20), at.next_at(time_in_day(9, 45))
  end

  def test_one_star_20
    at = Zhong::At.parse("*:45")

    assert_equal time_in_day(8, 45), at.next_at(time_in_day(8, 35))
    assert_equal time_in_day(9, 45), at.next_at(time_in_day(9, 35))
    assert_equal time_in_day(10, 45), at.next_at(time_in_day(9, 50))
  end

  def test_one_star_20_with_grace
    at = Zhong::At.parse("*:45", grace: 5.minutes)

    assert_equal time_in_day(8, 45), at.next_at(time_in_day(8, 35))
    assert_equal time_in_day(8, 45), at.next_at(time_in_day(8, 50))
    assert_equal time_in_day(9, 45), at.next_at(time_in_day(8, 51))
    assert_equal time_in_day(9, 45), at.next_at(time_in_day(9, 35))
    assert_equal time_in_day(10, 45), at.next_at(time_in_day(9, 55))
  end

  def test_16_two_stars
    at = Zhong::At.parse("16:**")

    assert_equal time_in_day(16, 00), at.next_at(time_in_day(8, 45))
    assert_equal time_in_day(16, 00), at.next_at(time_in_day(10, 00))
    assert_equal time_in_day(16, 00), at.next_at(time_in_day(16, 00))
    assert_equal time_in_day(16, 01), at.next_at(time_in_day(16, 01))
    assert_equal time_in_day(16, 30), at.next_at(time_in_day(16, 30))
    assert_equal time_in_day(16, 59), at.next_at(time_in_day(16, 59))
    assert_equal time_in_day(16, 00, 1), at.next_at(time_in_day(17, 00))
    assert_equal time_in_day(16, 00, 1), at.next_at(time_in_day(23, 59))
  end

  def test_8_two_stars
    at = Zhong::At.parse("8:**")

    assert_equal time_in_day(8, 00), at.next_at(time_in_day(3, 45))
    assert_equal time_in_day(8, 00), at.next_at(time_in_day(5, 00))
    assert_equal time_in_day(8, 00), at.next_at(time_in_day(8, 00))
    assert_equal time_in_day(8, 01), at.next_at(time_in_day(8, 01))
    assert_equal time_in_day(8, 30), at.next_at(time_in_day(8, 30))
    assert_equal time_in_day(8, 59), at.next_at(time_in_day(8, 59))
    assert_equal time_in_day(8, 00, 1), at.next_at(time_in_day(9, 00))
    assert_equal time_in_day(8, 00, 1), at.next_at(time_in_day(12, 59))
  end

  def test_saturday_12
    at = Zhong::At.parse("Saturday 12:00")

    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(12, 00))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(13, 00, 1))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(23, 59, 3))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(12, 00, 5))
    assert_equal time_in_day(12, 00, 12), at.next_at(time_in_day(12, 01, 5))
    assert_equal time_in_day(12, 00, 12), at.next_at(time_in_day(13, 01, 6, 01))
  end

  def test_sat_12
    at = Zhong::At.parse("sat 12:00")

    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(12, 00))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(13, 00, 1))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(23, 59, 3))
    assert_equal time_in_day(12, 00, 5), at.next_at(time_in_day(12, 00, 5))
    assert_equal time_in_day(12, 00, 12), at.next_at(time_in_day(12, 01, 5))
    assert_equal time_in_day(12, 00, 12), at.next_at(time_in_day(13, 01, 6, 01))
  end

  def test_tue_12_59
    at = Zhong::At.parse("tue 12:59")

    assert_equal time_in_day(12, 59, 1), at.next_at(time_in_day(7, 00))
    assert_equal time_in_day(12, 59, 1), at.next_at(time_in_day(12, 00, 1))
    assert_equal time_in_day(12, 59, 1), at.next_at(time_in_day(12, 59, 1))
    assert_equal time_in_day(12, 59, 8), at.next_at(time_in_day(13, 00, 1))
    assert_equal time_in_day(12, 59, 8), at.next_at(time_in_day(13, 01, 6, 01))
  end

  def test_thr_12_59
    at = Zhong::At.parse("thr 12:59")

    assert_equal time_in_day(12, 59, 3), at.next_at(time_in_day(7, 00))
    assert_equal time_in_day(12, 59, 3), at.next_at(time_in_day(12, 00, 3))
    assert_equal time_in_day(12, 59, 3), at.next_at(time_in_day(12, 59, 3))
    assert_equal time_in_day(12, 59, 10), at.next_at(time_in_day(13, 00, 3))
    assert_equal time_in_day(12, 59, 10), at.next_at(time_in_day(13, 01, 6, 01))
  end

  def test_invalid_time_32
    assert_raises Zhong::At::FailedToParse do
      Zhong::At.parse("32:00")
    end
  end

  def test_invalid_multi_line_time_sat_12
    assert_raises Zhong::At::FailedToParse do
      Zhong::At.parse("sat 12:00\nreally invalid time")
    end
  end
end
