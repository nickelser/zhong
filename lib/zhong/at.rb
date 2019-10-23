module Zhong
  # Strongly inspired by the Clockwork At class
  class At
    class FailedToParse < StandardError; end

    WDAYS = %w(sunday monday tuesday wednesday thursday friday saturday).each.with_object({}).with_index do |(w, wdays), index|
      [w, w[0...3]].each do |k|
        wdays[k] = index

        if k == "tue"
          wdays["tues"] = index
        elsif k == "thu"
          wdays["thr"] = index
        end
      end
    end.freeze

    attr_accessor :minute, :hour, :wday

    def self.parse(at, grace: 0.seconds)
      if at.respond_to?(:each)
        MultiAt.new(at.map { |a| parse_at(a, grace) })
      else
        parse_at(at, grace)
      end
    rescue ArgumentError
      raise FailedToParse, at
    end

    def self.deserialize(at)
      parse_serialized(MessagePack.unpack(at))
    end

    def initialize(minute: nil, hour: nil, wday: nil, grace: 0.seconds)
      @minute = minute
      @hour = hour
      @wday = wday
      @grace = grace

      raise ArgumentError unless valid?
    end

    def prev_at(time = Time.now)
      at_time = at_time_day_hour_minute_adjusted(time)

      grace_cutoff = time.change(sec: 0) - @grace

      if at_time >= grace_cutoff
        at_time - if @wday.nil?
                    @hour.nil? ? 1.hour : 1.day
                  else
                    1.week
                  end
      else
        at_time
      end
    end

    def next_at(time = Time.now)
      at_time = at_time_day_hour_minute_adjusted(time)

      grace_cutoff = time.change(sec: 0) - @grace

      if at_time <= grace_cutoff
        at_time + if @wday.nil?
                    @hour.nil? ? 1.hour : 1.day
                  else
                    1.week
                  end
      else
        at_time
      end
    end

    def to_s
      str = "#{formatted_time(@hour)}:#{formatted_time(@minute)}"
      str += " on #{WDAYS.invert[@wday].capitalize}" if @wday

      str
    end

    def as_json
      {m: @minute, h: @hour, w: @wday, g: @grace}
    end

    def serialize
      MessagePack.pack(as_json)
    end

    def ==(other)
      other.class == self.class && other.state == state
    end

    def self.parse_serialized(at)
      if at.is_a?(Array)
        MultiAt.new(at.map { |a| parse_serialized(a) })
      else
        new(minute: at["m"], hour: at["h"], wday: at["w"], grace: at["g"])
      end
    end
    private_class_method :parse_serialized

    def self.parse_at(at, grace)
      case at
      when /\A([[:alpha:]]+)\s+(.*)\z/
        wday = WDAYS[$1.downcase]

        raise FailedToParse, at unless wday

        parsed_time = parse_at($2, grace)
        parsed_time.wday = wday
        parsed_time
      when /\A(\d{1,2}):(\d\d)\z/
        new(minute: $2.to_i, hour: $1.to_i, grace: grace)
      when /\A\*{1,2}:(\d\d)\z/
        new(minute: $1.to_i, grace: grace)
      when /\A(\d{1,2}):\*{1,2}\z/
        new(hour: $1.to_i, grace: grace)
      when /\A\*{1,2}:\*{1,2}\z/
        new(grace: grace)
      else
        raise FailedToParse, at
      end
    end
    private_class_method :parse_at

    protected

    def formatted_time(t)
      if t.nil?
        "**"
      else
        t.to_s.rjust(2, "0")
      end
    end

    def state
      [@minute, @hour, @wday]
    end

    private

    def at_time_hour_minute_adjusted(time)
      if @minute && @hour
        time.change(hour: @hour, min: @minute)
      elsif @minute
        time.change(min: @minute)
      elsif @hour && @hour != time.hour
        time.change(hour: @hour)
      else
        time.change(sec: 0)
      end
    end

    def at_time_day_hour_minute_adjusted(time)
      at_time_hour_minute_adjusted(time) + (@wday ? (@wday - time.wday) : 0).days
    end

    def valid?
      (@minute.nil? || (0..59).cover?(@minute)) &&
        (@hour.nil? || (0..23).cover?(@hour)) &&
        (@wday.nil? || (0..6).cover?(@wday))
    end
  end

  class MultiAt
    attr_accessor :ats

    def initialize(ats = [])
      @ats = ats
    end

    def ==(other)
      other.class == self.class && @ats == other.ats
    end

    def prev_at(time = Time.now)
      ats.map { |at| at.prev_at(time) }.max
    end

    def next_at(time = Time.now)
      ats.map { |at| at.next_at(time) }.min
    end

    def to_s
      ats.map(&:to_s).join(", ")
    end

    def as_json
      ats.map(&:as_json)
    end

    def serialize
      MessagePack.pack(as_json)
    end
  end
end
