module Zhong
  class Job
    attr_reader :name, :category

    def initialize(name, config = {}, &block)
      @name = name
      @category = config[:category]

      @at = At.parse(config[:at], grace: config.fetch(:grace, 15.minutes))
      @every = Every.parse(config[:every])

      if @at && !@every
        @logger.error "warning: #{self} has `at` but no `every`; could run far more often than expected!"
      end

      fail "must specific either `at` or `every` for a job" unless @at || @every

      @block = block

      @redis = config[:redis]
      @logger = config[:logger]
      @tz = config[:tz]
      @if = config[:if]
      @lock = Suo::Client::Redis.new(lock_key, client: @redis, stale_lock_expiration: config[:long_running_timeout])
      @timeout = 5

      refresh_last_ran
    end

    def run?(time = Time.now)
      run_every?(time) && run_at?(time) && run_if?(time)
    end

    def run(time = Time.now)
      return unless run?(time)

      if running?
        @logger.info "already running: #{self}"
        return
      end

      @thread = nil
      locked = false

      @lock.lock do
        locked = true

        refresh_last_ran

        # we need to check again, as another process might have acquired
        # the lock right before us and obviated our need to do anything
        break unless run?(time)

        if disabled?
          @logger.info "disabled: #{self}"
          break
        end

        @logger.info "running: #{self}"

        @thread = Thread.new { @block.call } if @block

        ran!(time)
      end

      @logger.info "unable to acquire exclusive run lock: #{self}" unless locked
    end

    def stop
      return unless running?
      Thread.new { @logger.error "killing #{self} due to stop" } # thread necessary due to trap context
      @thread.join(@timeout)
      @thread.kill
    end

    def running?
      @thread && @thread.alive?
    end

    def refresh_last_ran
      last_ran_val = @redis.get(run_time_key)
      @last_ran = last_ran_val ? Time.at(last_ran_val.to_i) : nil
    end

    def disable
      @redis.set(disabled_key, "true")
    end

    def enable
      @redis.del(disabled_key)
    end

    def disabled?
      !!@redis.get(disabled_key)
    end

    def to_s
      [@category, @name].compact.join(".").freeze
    end

    def next_at
      every_time = @every.next_at(@last_ran) if @last_ran && @every
      at_time = @at.next_at(Time.now) if @at
      [every_time, at_time, Time.now].compact.max || "now"
    end

    private

    def run_every?(time)
      !@last_ran || !@every || @every.next_at(@last_ran) <= time
    end

    def run_at?(time)
      !@at || @at.next_at(time) <= time
    end

    def run_if?(time)
      !@if || @if.call(time)
    end

    def ran!(time)
      @last_ran = time
      @redis.set(run_time_key, @last_ran.to_i)
    end

    def run_time_key
      "zhong:last_ran:#{self}"
    end

    def disabled_key
      "zhong:disabled:#{self}"
    end

    def lock_key
      "zhong:lock:#{self}"
    end
  end
end
