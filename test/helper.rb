$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

if ENV["CODECLIMATE_REPO_TOKEN"]
  require "codeclimate-test-reporter"
  ::SimpleCov.add_filter "**/*helper*"
  CodeClimate::TestReporter.start
end

require "zhong"
require "minitest/autorun"
require "rack/test"

ENV["RACK_ENV"] = ENV["RAILS_ENV"] = "test"

def assert_contains(expected_substring, string, *args)
  assert string.include?(expected_substring), *args
end

def test_logger
  @logger ||= begin
    l = Logger.new(STDOUT)
    l.level = Logger::ERROR
    l
  end
end

def test_default_config
  @default_config ||= {
    redis: Redis.new(url: ENV["REDIS_URL"] || "redis://localhost/13"),
    logger: test_logger,
    long_running_timeout: 10.seconds
  }
end
