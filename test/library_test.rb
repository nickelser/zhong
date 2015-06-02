require "test_helper"

class TestLibrary < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Zhong::VERSION
  end
end
