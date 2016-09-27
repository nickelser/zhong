module Zhong
  class Scheduler
    attr_reader :config, :redis, :jobs, :logger

    DEFAULT_CONFIG = {
      timeout: 0.5,
      grace: 15.minutes,
      long_running_timeout: 5.minutes,
      tz: nil,
      heartbeat_key: "zhong:heartbeat",
    }.freeze

    def initialize(config = {})
      @jobs = {}
      @callbacks = {}
      @config = DEFAULT_CONFIG.merge(config)

      @logger = @config[:logger]
      @redis = @config[:redis]
      @tz = @config[:tz]
      @category = nil
      @error_handler = nil
      @running = false
    end

    def clear
      raise "unable to clear while running; run Zhong.stop first" if @running

      @jobs = {}
      @callbacks = {}
      @category = nil
    end

    def category(name)
      raise "cannot nest categories: #{name} would be nested in #{@category} (#{caller.first})" if @category

      @category = name.to_s

      yield(self)

      @category = nil
    end

    def every(period, name, opts = {}, &block)
      raise "must specify a period for #{name} (#{caller.first})" unless period

      job = Job.new(name, opts.merge(@config).merge(every: period, category: @category), @callbacks, &block)

      raise "duplicate job #{job}" if jobs.key?(job.id)

      @jobs[job.id] = job
    end

    def error_handler(&block)
      @error_handler = block if block_given?
      @error_handler
    end

    def on(event, &block)
      raise "unknown callback #{event}" unless [:before_tick, :after_tick, :before_run, :after_run, :before_disable, :after_disable, :before_enable, :after_enable].include?(event.to_sym)
      (@callbacks[event.to_sym] ||= []) << block
    end

    def start
      logger.info "starting at #{redis_time}"

      @stop = false

      trap_signals

      raise "already running" if @running

      loop do
        @running = true

        if fire_callbacks(:before_tick)
          now = redis_time

          jobs_to_run(now).each do |_, job|
            break if @stop
            run_job(job, now)
          end

          break if @stop

          fire_callbacks(:after_tick)

          heartbeat(now)

          break if @stop
        else
          logger.info "skipping tick due to a `:before_tick` callback"
        end

        sleep_until_next_second

        break if @stop
      end

      @running = false

      Thread.new { logger.info "stopped" }.join
    end

    def stop
      Thread.new { logger.error "stopping" } if @running # thread necessary due to trap context
      @stop = true
    end

    def find_by_name(job_name)
      @jobs[Digest::SHA256.hexdigest(job_name)]
    end

    def redis_time
      s, ms = @redis.time # returns [seconds since epoch, microseconds]
      now = Time.at(s + ms / (10**6))
      @tz ? now.in_time_zone(@tz) : now
    end

    private

    TRAPPED_SIGNALS = %w(QUIT INT TERM).freeze
    private_constant :TRAPPED_SIGNALS

    def fire_callbacks(event, *args)
      @callbacks[event].to_a.map do |callback|
        callback.call(*args)
      end.compact.all? # do not skip on nils
    end

    def jobs_to_run(time = redis_time)
      jobs.select { |_, job| job.run?(time) }
    end

    def run_job(job, time = redis_time)
      unless fire_callbacks(:before_run, job, time)
        logger.info "skipping #{job} due to a `:before_run` callback"
        return
      end

      ran = job.run(time, error_handler)

      fire_callbacks(:after_run, job, time, ran)
    end

    def heartbeat(time)
      @redis.hset(config[:heartbeat_key], heartbeat_field, time.to_i)
    end

    def heartbeat_field
      @heartbeat_field ||= "#{`hostname`.strip}##{Process.pid}"
    end

    def trap_signals
      TRAPPED_SIGNALS.each do |sig|
        Signal.trap(sig) { stop }
      end
    end

    def sleep_until_next_second
      GC.start
      sleep(1.0 - Time.now.subsec + 0.0001)
    end
  end
end
