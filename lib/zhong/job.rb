module Zhong
  class Job
    attr_reader :name, :category, :last_ran, :logger

    def initialize(name, config = {}, &block)
      @name = name
      @category = config[:category]
      @logger = config[:logger]

      @at = At.parse(config[:at], grace: config.fetch(:grace, 15.minutes)) if config[:at]
      @every = Every.parse(config[:every]) if config[:every]

      fail "must specific either `at` or `every` for job: #{self}" unless @at || @every

      @block = block

      @redis = config[:redis]
      @tz = config[:tz]
      @if = config[:if]
      @long_running_timeout = config[:long_running_timeout]
      @running = false

      refresh_last_ran
    end

    def run?(time = Time.now)
      run_every?(time) && run_at?(time) && run_if?(time)
    end

    def run(time = Time.now, error_handler = nil)
      return unless run?(time)

      locked = false
      errored = false

      begin
        redis_lock.lock do
          locked = true
          @running = true

          refresh_last_ran

          # we need to check again, as another process might have acquired
          # the lock right before us and obviated our need to do anything
          break unless run?(time)

          if disabled?
            logger.info "disabled: #{self}"
            break
          end

          logger.info "running: #{self}"

          if @block
            begin
              @block.call
            rescue => boom
              logger.error "#{self} failed: #{boom}"
              error_handler.call(boom, self) if error_handler
            end
          end

          ran!(time)
        end
      rescue Suo::LockClientError => boom
        logger.error "unable to run due to client error: #{boom}"
        errored = true
      end

      @running = false

      logger.info "unable to acquire exclusive run lock: #{self}" if !locked && !errored
    end

    def running?
      @running
    end

    def refresh_last_ran
      last_ran_val = @redis.get(last_ran_key)
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

    def clear
      @redis.del(last_ran_key)
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
      @redis.set(last_ran_key, @last_ran.to_i)
    end

    def redis_lock
      @lock ||= Suo::Client::Redis.new(lock_key, client: @redis, stale_lock_expiration: @long_running_timeout)
    end

    def last_ran_key
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
