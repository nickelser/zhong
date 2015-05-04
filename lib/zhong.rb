require "zhong/version"
require "monitor"
require "logger"
require "redis"
require "suo"

module Zhong
  class Job
    attr_reader :description, :name, :category

    def initialize(manager:, name:, every:, description: nil, category: nil, &block)
      @every = every
      @description = description
      @category = category
      @block = block
      @redis = manager.config[:redis]
      @logger = manager.config[:logger]
      @name = name
      @lock = Suo::Client::Redis.new(lock_key, client: @redis)
      @timeout = 5

      refresh_last_ran
    end

    def run?(time = Time.now)
      !@last_ran || next_run_at < time
    end

    def run(time = Time.now)
      return unless run?(time)

      if running?
        @logger.info "already running: #{@name}"
        return
      end

      ran_set = @lock.lock do
        refresh_last_ran

        break unless run?(time)

        if disabled?
          @logger.info "disabled: #{@name}"
          break
        end

        @logger.info "running: #{@name}"

        @thread = Thread.new { @block.call } if @block

        ran!(time)
      end

      @logger.info "unable to acquire exclusive run lock: #{@name}" unless ran_set
    end

    def stop
      return unless running?
      Thread.new { @logger.error "killing #{@name} due to stop" } # thread necessary due to trap context
      @thread.join(@timeout)
      @thread.kill
    end

    def running?
      @thread && @thread.alive?
    end

    def next_run_at
      @last_ran ? (@last_ran + @every) : (Time.now - 0.001)
    end

    def refresh_last_ran
      last_ran_val = @redis.get(run_time_key)
      @last_ran = last_ran_val ? Time.at(last_ran_val.to_i) : nil
    end

    def disabled?
      !!@redis.get(disabled_key)
    end

    private

    def ran!(time)
      @last_ran = time
      @redis.set(run_time_key, @last_ran.to_i)
    end

    def run_time_key
      "zhong:last_ran:#{@name}"
    end

    def disabled_key
      "zhong:disabled:#{@name}"
    end

    def lock_key
      "zhong:lock:#{@name}"
    end
  end

  class Manager
    attr_reader :config, :redis

    def initialize(config = {})
      @jobs = []
      @config = {timeout: 0.5, tz: "UTC"}.merge(config)
      @logger = @config[:logger] ||= default_logger
      @redis = @config[:redis] ||= Redis.new
    end

    def start
      %w(QUIT INT TERM).each do |sig|
        Signal.trap(sig) { stop }
      end

      @logger.info "starting"

      loop do
        tick

        break if @stop
      end
    end

    def stop
      Thread.new { @logger.error "stopping" } # thread necessary due to trap context
      @stop = true
      @jobs.each(&:stop)
      Thread.new { @logger.info "stopped" }
    end

    def add(job)
      @jobs << job
    end

    def tick
      now = redis_time

      @jobs.each { |job| job.run(now) }

      sleep(interval)
    end

    def interval
      1.0 - Time.now.subsec + 0.001
    end

    def redis_time
      s, ms = @redis.time # returns [seconds since epoch, microseconds]
      Time.at(s + ms / (10**6))
    end

    def default_logger
      Logger.new(STDOUT).tap do |logger|
        logger.formatter = -> (_, datetime, _, msg) { "#{datetime}: #{msg}\n" }
      end
    end
  end

  class << self
    def included(klass)
      klass.send "include", Methods
      klass.extend Methods
    end

    def manager
      @manager ||= Manager.new
    end

    def manager=(manager)
      @manager = manager
    end
  end

  module Methods
    def configure(&block)
      self.manager.configure(&block)
    end

    # def handler(&block)
    #   self.manager.handler(&block)
    # end

    # def error_handler(&block)
    #   self.manager.error_handler(&block)
    # end

    def on(event, options={}, &block)
      self.manager.on(event, options, &block)
    end

    def every(period, job, options={}, &block)
      self.manager.every(period, job, options, &block)
    end

    def run
      self.manager.run
    end
  end

  extend Methods
end


r = Redis.new

x = Zhong::Manager.new(redis: r)

j = Zhong::Job.new(manager: x, name: "j1", every: 10) { puts "FUCK THIS SHIT YOLOOOOO" }
j2 = Zhong::Job.new(manager: x, name: "j2", every: 15) { puts "FUCK UuuuuuuuUUUUUU" }
j3 = Zhong::Job.new(manager: x, name: "j3", every: 10) { puts "FUCK THIS SHIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!" }
j4 = Zhong::Job.new(manager: x, name: "j4", every: 5) { sleep 8; puts "RAN FUCK SHIT" }

x.add(j)
x.add(j2)
x.add(j3)
x.add(j4)
x.start
