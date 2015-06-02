module Zhong
  class Scheduler
    attr_reader :config, :redis, :jobs

    DEFAULT_CONFIG = {
      timeout: 0.5,
      grace: 15.minutes,
      long_running_timeout: 5.minutes
    }.freeze

    def initialize(config = {})
      @jobs = {}
      @callbacks = {}
      @config = DEFAULT_CONFIG.merge(config)
      @logger = @config[:logger] ||= Util.default_logger
      @redis = @config[:redis] ||= Redis.new(ENV["REDIS_URL"])
    end

    def category(name)
      fail "cannot nest categories: #{name} would be nested in #{@category} (#{caller.first})" if @category

      @category = name.to_s

      yield(self)

      @category = nil
    end

    def every(period, name, opts = {}, &block)
      fail "must specify a period for #{name} (#{caller.first})" unless period
      job = Job.new(name, opts.merge(@config).merge(every: period, category: @category), &block)
      add(job)
    end

    def error_handler(&block)
      @error_handler = block if block_given?
      @error_handler
    end

    def on(event, &block)
      fail "unknown callback #{event}" unless [:before_tick, :after_tick, :before_run, :after_run].include?(event.to_sym)
      (@callbacks[event.to_sym] ||= []) << block
    end

    def start
      @logger.info "starting at #{redis_time}"

      trap_signals

      loop do
        if fire_callbacks(:before_tick)
          now = redis_time

          jobs_to_run(now).each do |_, job|
            run_job(job, now)
          end

          fire_callbacks(:after_tick)

          sleep_until_next_tick
        end

        break if @stop
      end
    end

    def stop
      Thread.new { @logger.error "stopping" } # thread necessary due to trap context
      @stop = true
      jobs.values.each(&:stop)
      Thread.new { @logger.info "stopped" }
    end

    def fire_callbacks(event, *args)
      @callbacks[event].to_a.all? { |h| h.call(*args) }
    end

    def jobs_to_run(time = redis_time)
      jobs.select { |_, job| job.run?(time) }
    end

    def run_job(job, time = redis_time)
      return unless fire_callbacks(:before_run, job, time)

      job.run(time, error_handler)

      fire_callbacks(:after_run, job, time)
    end

    private

    TRAPPED_SIGNALS = %w(QUIT INT TERM).freeze
    private_constant :TRAPPED_SIGNALS

    def trap_signals
      TRAPPED_SIGNALS.each do |sig|
        Signal.trap(sig) { stop }
      end
    end

    def add(job)
      if @jobs.key?(job.to_s)
        @logger.error "duplicate job #{job}, skipping"
        return
      end

      @jobs[job.to_s] = job
    end

    def sleep_until_next_tick
      GC.start
      sleep(1.0 - Time.now.subsec + 0.001)
    end

    def redis_time
      s, ms = @redis.time # returns [seconds since epoch, microseconds]
      now = Time.at(s + ms / (10**6))
      config[:tz] ? now.in_time_zone(config[:tz]) : now
    end
  end
end
