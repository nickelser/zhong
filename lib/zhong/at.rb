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
      at_time = @wday.nil? ? time.dup : (time + (@wday - time.wday).days)

      at_time = if !@minute.nil? && !@hour.nil?
        at_time.change(hour: @hour, min: @minute)
      elsif !@minute.nil?
        at_time.change(min: @minute)
      elsif !@hour.nil? && @hour != time.hour
        at_time.change(hour: @hour)
      else
        at_time.change(sec: 0)
      end

      if at_time < (time.change(sec: 0) - @grace)
        if @wday.nil?
          if @hour.nil?
            at_time += 1.hour
          else
            at_time += 1.day
          end
        else
          at_time += 1.week
        end
      else
        at_time
      end
    end

    private def valid?
      (@minute.nil? || (0..59).cover?(@minute)) &&
        (@hour.nil? || (0..23).cover?(@hour)) &&
        (@wday.nil? || (0..6).cover?(@wday))
    end

    def self.parse(at, grace: 0.seconds)
      return unless at

      # TODO: refactor this mess
      if at.respond_to?(:each)
        return MultiAt.new(at.map { |a| parse(a, grace: grace) })
      end

      case at
      when /\A([[:alpha:]]+)\s+(.*)\z/
        wday = WDAYS[$1.downcase]

        if wday
          parsed_time = parse($2, grace: grace)
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
    rescue ArgumentError
      fail FailedToParse, at
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
