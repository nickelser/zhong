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

    def initialize(minute: nil, hour: nil, wday: nil, grace: 0.minutes)
      @minute = minute
      @hour = hour
      @wday = wday
      @grace = grace
    end

    def next_at(time = Time.now)
      at_time = @wday.nil? ? time.dup : (time + (@wday - time.wday).days)

      at_time = at_time.change(min: @minute)
      at_time = at_time.change(hour: @hour) if @hour

      if at_time < @grace.ago
        if @wday.nil?
          at_time += 1.day
        else
          at_time += 1.week
        end
      else
        at_time
      end
    end

    def self.parse(at, grace: 0)
      return unless at

      # TODO: refactor this mess
      if at.respond_to?(:each)
        return MultiAt.new(at.map { |a| parse(a, grace: grace) })
      end

      case at
      when /\A([[:alpha:]]+)\s+(.*)\z/
        wday = WDAYS[$1]

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
        new(hour: $1, grace: grace)
      else
        fail FailedToParse, at
      end
    rescue ArgumentError
      throw FailedToParse, at
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
