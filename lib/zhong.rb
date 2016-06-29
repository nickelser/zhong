require "digest"
require "logger"
require "msgpack"
require "redis"
require "suo"
require "active_support/time"

require "zhong/version"

require "zhong/every"
require "zhong/at"

require "zhong/job"
require "zhong/scheduler"

module Zhong
  class << self
    attr_writer :logger, :redis
    attr_accessor :tz
  end

  def self.schedule(&block)
    scheduler.instance_eval(&block) if block_given?
  end

  def self.start
    scheduler.start
  end

  def self.stop
    scheduler.stop
  end

  def self.clear
    scheduler.clear
  end

  def self.scheduler
    @scheduler ||= Scheduler.new(logger: logger, redis: redis, tz: tz)
  end

  def self.jobs
    scheduler.jobs
  end

  def self.logger
    @logger ||= Logger.new(STDOUT).tap do |logger|
      logger.formatter = -> (_, datetime, _, msg) { "#{datetime}: #{msg}\n" }
    end
  end

  def self.redis
    @redis ||= Redis.new(url: ENV["REDIS_URL"])
  end
end
