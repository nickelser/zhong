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

    def initialize(minute: nil, hour: nil, wday: nil, grace: 0.seconds)
      @minute = minute
      @hour = hour
      @wday = wday
      @grace = grace

      fail ArgumentError unless valid?
    end

    def next_at(time = Time.now)
      at_time = at_time_day_hour_minute_adjusted(time)

      grace_cutoff = time.change(sec: 0) - @grace

      if at_time < grace_cutoff
        if @wday.nil?
          at_time += @hour.nil? ? 1.hour : 1.day
        else
          at_time += 1.week
        end
      else
        at_time
      end
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

    class << self
      def parse(at, grace: 0.seconds)
        if at.respond_to?(:each)
          MultiAt.new(at.map { |a| parse_at(a, grace) })
        else
          parse_at(at, grace)
        end
      rescue ArgumentError
        fail FailedToParse, at
      end

      private

      def parse_at(at, grace)
        case at
        when /\A([[:alpha:]]+)\s+(.*)\z/
          wday = WDAYS[$1.downcase]

          if wday
            parsed_time = parse_at($2, grace)
            parsed_time.wday = wday
            parsed_time
          else
            fail FailedToParse, at
          end
        when /\A(\d{1,2}):(\d\d)\z/
          new(minute: $2.to_i, hour: $1.to_i, grace: grace)
        when /\A\*{1,2}:(\d\d)\z/
          new(minute: $1.to_i, grace: grace)
        when /\A(\d{1,2}):\*{1,2}\z/
          new(hour: $1.to_i, grace: grace)
        else
          fail FailedToParse, at
        end
      end
    end
  end

  class MultiAt
    attr_accessor :ats

    def initialize(ats = [])
      @ats = ats
    end

    def next_at(time = Time.now)
      ats.map { |at| at.next_at(time) }.min
    end
  end
end
