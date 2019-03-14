module Zhong
  class Job
    extend Forwardable
    def_delegators Zhong, :redis, :tz, :logger, :heartbeat_key

    attr_reader :name, :category, :last_ran, :at, :every, :id, :owner, :with_owner

    def initialize(job_name, config = {}, callbacks = {}, &block)
      @name = job_name
      @category = config[:category]
      @logger = config[:logger]
      @config = config
      @callbacks = callbacks

      @at = config[:at] ? At.parse(config[:at], grace: config.fetch(:grace, 15.minutes)) : nil
      @every = config[:every] ? Every.parse(config[:every]) : nil

      raise "must specific either `at` or `every` for job: #{self}" unless @at || @every

      @block = block

      @if = config[:if]
      @long_running_timeout = config[:long_running_timeout]
      @with_ownership_class = config[:with_ownership_class] # class
      @with_ownership_method = config[:with_ownership_method] # symbol
      @owner = config[:owner]
      @with_owner = @owner.present? && rollbar_with_owner_method.present?
      @running = false
      @first_run = true
      @last_ran = nil
      @id = Digest::SHA256.hexdigest(@name)
    end

    def run?(time = Time.now)
      if @first_run
        clear_last_ran_if_at_changed if @at
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
              if with_owner
                rollbar_with_owner_method.call(owner, &@block)
              else
                @block.call
              end
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

    def clear
      redis.del(last_ran_key)
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

    # if the @at value is changed across runs, the last_run becomes invalid
    # so clear it
    def clear_last_ran_if_at_changed
      previous_at_msgpack = redis.get(desired_at_key)

      if previous_at_msgpack
        previous_at = At.deserialize(previous_at_msgpack)

        if previous_at != @at
          logger.error "#{self} period changed (from #{previous_at} to #{@at}), clearing last run"
          clear
        end
      end

      redis.set(desired_at_key, @at.serialize)
    end

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
      redis.set(last_ran_key, @last_ran.to_i)
    end

    def redis_lock
      @lock ||= Suo::Client::Redis.new(lock_key, client: redis, stale_lock_expiration: @long_running_timeout)
    end

    def rollbar_with_owner_method
      @with_ownership_class.method(@with_ownership_method)
    rescue NameError => e
    end

  end
end
