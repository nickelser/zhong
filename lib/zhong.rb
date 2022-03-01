require "digest"
require "forwardable"
require "logger"
require "msgpack"
require "redis"
require "suo"
require "active_support"
require "active_support/time"

require "zhong/version"
require "zhong/util"

require "zhong/every"
require "zhong/at"

require "zhong/job"
require "zhong/scheduler"

module Zhong
  class << self
    extend Forwardable
    attr_writer :logger, :redis, :heartbeat_key
    attr_accessor :tz

    def_delegators :scheduler, :start, :stop, :clear, :jobs, :redis_time
  end

  def self.schedule(&block)
    scheduler.instance_eval(&block) if block_given?
  end

  def self.scheduler
    @scheduler ||= Scheduler.new
  end

  def self.any_running?(grace = 60.seconds)
    latest_heartbeat && latest_heartbeat > (redis_time - grace)
  end

  def self.latest_heartbeat
    all_heartbeats.map { |h| h[:last_seen] }.sort.last
  end

  def self.all_heartbeats
    heartbeats = redis.hgetall(heartbeat_key)
    now = redis_time

    old_beats, new_beats = heartbeats.partition do |_, v|
      Time.at(v.to_i) < (now - 15.minutes)
    end

    redis.multi do
      old_beats.each { |b| redis.hdel(heartbeat_key, b) }
    end

    new_beats.map do |k, v|
      host, pid = k.split("#", 2)
      {host: host, pid: pid, last_seen: Time.at(v.to_i)}
    end
  end

  def self.logger
    @logger ||= Logger.new(STDOUT).tap do |logger|
      logger.formatter = -> (_, datetime, _, msg) { "#{datetime}: #{msg}\n" }
    end
  end

  def self.redis
    @redis ||= Redis.new(url: ENV["REDIS_URL"])
  end

  def self.heartbeat_key
    @heartbeat_key ||= "zhong:heartbeat"
  end
end
