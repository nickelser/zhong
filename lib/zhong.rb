require "zhong/version"
require "monitor"
require "redis"
require "suo"

module Zhong
  class Job
    def initialize(description, redis:, every:, &block)
      #@at = at
      @every = every
      @description = description
      @block = block
      @redis = redis
      @lock = Suo::Client::Redis.new("zhong:lock:#{description}", client: redis)
      @last_ran = last_ran
    end

    def run?(time = Time.now, refresh: false)
      puts "run? #{@description} #{next_run_at(refresh: refresh)} #{next_run_at(refresh: refresh) < time}"
      next_run_at(refresh: refresh) < time
    end

    def last_ran
      last_ran_val = @redis.get(run_time_key)
      last_ran_val ? Time.at(last_ran_val.to_i) : nil
    end

    def run
      puts "runnin dis shit: #{@description}"
      @lock.lock do
        next unless run?(refresh: true)

        puts "RUNNING #{@description}"

        if @block
          @block.call # no error handler - we do not want ran! to execute if failed
        end

        ran!
      end
    end

    def ran!
      @last_ran = now = Time.now
      @redis.set(run_time_key, now.to_i)
    end

    def next_run_at(refresh: false)
      last_ran_time = refresh ? last_ran : @last_ran

      last_ran_time ? (last_ran_time + @every) : (Time.now - 1)
    end

    def run_time_key
      "zhong:last_ran:#{@description}"
    end
  end

  class Manager
    include MonitorMixin

    def initialize(redis:)
      @redis = redis
      @jobs = []
    end

    def start
      loop do
        tick
      end
    end

    def add(job)
      @jobs << job
    end

    def tick
      @jobs.select(&:run?).each do |job|
        begin
          job.run
        rescue => boom
          puts "crap: #{boom.to_s}"
        end
      end

      sleep sleep_time
    end

    def sleep_time
      0.5
    end
  end
end

r = Redis.new

x = Zhong::Manager.new(redis: r)

j = Zhong::Job.new("yolo", redis: r, every: 10) { puts "FUCK THIS SHIT YOLOOOOO" }
j2 = Zhong::Job.new("fuck yea", redis: r, every: 15) { "FUCK UuuuuuuuUUUUUU" }

x.add(j)
x.add(j2)
x.start
