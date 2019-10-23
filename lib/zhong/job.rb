module Zhong
  class Job
    extend Forwardable
    def_delegators Zhong, :redis, :tz, :logger, :heartbeat_key

    attr_reader :name, :category, :last_ran, :at, :every, :id

    def initialize(job_name, config = {}, callbacks = {}, &block)
      @name = job_name
      @category = config[:category]
      @logger = config[:logger]
      @config = config
      @callbacks = callbacks

      @at = config[:at] ? At.parse(config[:at], grace: config.fetch(:grace, 0.minutes)) : nil
      @every = config[:every] ? Every.parse(config[:every]) : nil

      raise "must specific either `at` or `every` for job: #{self}" unless @at || @every

      @block = block

      @if = config[:if]
      @long_running_timeout = config[:long_running_timeout]
      @running = false
      @first_run = true
      @last_ran = nil
      @id = Digest::SHA256.hexdigest(@name)
    end

    def run?(time = Time.now)
      if @first_run
        setup_at if @at
        refresh_last_ran
        @first_run = false
      end

      run_every?(time) && run_at?(time) && run_if?(time)
    end

    def run(time = Time.now, error_handler = nil)
      return unless run?(time)

      locked = false
      errored = false
      ran = false

      begin
        redis_lock.lock do
          locked = true
          @running = true

          refresh_last_ran

          # we need to check again, as another process might have acquired
          # the lock right before us and obviated our need to do anything
          break unless run?(time)

          if disabled?
            logger.info "not running, disabled: #{self}"
            break
          end

          logger.info "running: #{self}"

          if @block
            begin
              @block.call
              ran = true
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

      ran
    end

    def running?
      @running
    end

    def refresh_last_ran
      last_ran_val = redis.get(last_ran_key)
      @last_ran = last_ran_val ? Time.at(last_ran_val.to_i) : nil
    end

    def disable
      fire_callbacks(:before_disable, self)
      redis.set(disabled_key, "true")
      fire_callbacks(:after_disable, self)
    end

    def enable
      fire_callbacks(:before_enable, self)
      redis.del(disabled_key)
      fire_callbacks(:after_enable, self)
    end

    def disabled?
      !redis.get(disabled_key).nil?
    end

    def to_s
      @to_s ||= [@category, @name].compact.join(".").freeze
    end

    def next_at
      every_time = @every.next_at(@last_ran) if @last_ran && @every
      at_time = @at.next_at(Time.now) if @at
      [every_time, at_time, Time.now].compact.max || "now"
    end

    def last_ran_key
      "zhong:last_ran:#{self}"
    end

    def desired_at_key
      "zhong:at:#{self}"
    end

    def disabled_key
      "zhong:disabled:#{self}"
    end

    def lock_key
      "zhong:lock:#{self}"
    end

    private

    def fire_callbacks(event, *args)
      @callbacks[event].to_a.map do |callback|
        callback.call(*args)
      end.compact.all? # do not skip on nils
    end

    def setup_at
      redis.set(last_ran_key, @at.prev_at(Time.now).to_i)
      redis.set(desired_at_key, @at.serialize)
    end

    def run_every?(time)
      !@last_ran || !@every || @every.next_at(@last_ran) <= time
    end

    def run_at?(time)
      !@at || @at.next_at(@last_ran) <= time
    end

    def run_if?(time)
      !@if || @if.call(time)
    end

    def ran!(time)
      @last_ran = time
      redis.set(last_ran_key, @last_ran.to_i)
    end

    def redis_lock
      @lock ||= Suo::Client::Redis.new(lock_key, client: redis, stale_lock_expiration: @long_running_timeout)
    end
  end
end
