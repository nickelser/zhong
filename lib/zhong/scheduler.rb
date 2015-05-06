module Zhong
  class Scheduler
    attr_reader :config, :redis, :jobs

    DEFAULT_CONFIG = {
      timeout: 0.5,
      grace: 15.minutes,
      long_running_timeout: 5.minutes
    }.freeze

    TRAPPED_SIGNALS = %w(QUIT INT TERM).freeze

    def initialize(config = {})
      @jobs = {}
      @config = DEFAULT_CONFIG.merge(config)
      @logger = @config[:logger] ||= Util.default_logger
      @redis = @config[:redis] ||= Redis.new(ENV["REDIS_URL"])
    end

    def category(name)
      fail "cannot nest categories: #{name} would be nested in #{@category}" if @category

      @category = name.to_s

      yield(self)

      @category = nil
    end

    def every(period, name, opts = {}, &block)
      add(Job.new(name, opts.merge(@config).merge(every: period, category: @category), &block))
    end

    def start
      TRAPPED_SIGNALS.each do |sig|
        Signal.trap(sig) { stop }
      end

      @logger.info "starting at #{redis_time}"

      loop do
        now = redis_time

        jobs.each { |_, job| job.run(now) }

        sleep(interval)

        break if @stop
      end
    end

    def stop
      Thread.new { @logger.error "stopping" } # thread necessary due to trap context
      @stop = true
      jobs.values.each(&:stop)
      Thread.new { @logger.info "stopped" }
    end

    private

    def add(job)
      if @jobs.key?(job.to_s)
        @logger.error "duplicate job #{job}, skipping"
        return
      end

      @jobs[job.to_s] = job
    end

    def interval
      1.0 - Time.now.subsec + 0.001
    end

    def redis_time
      s, ms = @redis.time # returns [seconds since epoch, microseconds]
      now = Time.at(s + ms / (10**6))
      config[:tz] ? now.in_time_zone(config[:tz]) : now
    end
  end
end
