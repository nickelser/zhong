module Zhong
  class Every
    class FailedToParse < StandardError; end

    EVERY_KEYWORDS = {
      minute: 1.minute,
      hour: 1.hour,
      day: 1.day,
      week: 1.week,
      month: 1.month,
      year: 1.year,
      decade: 10.years
    }.freeze

    def initialize(period)
      @period = period

      raise "`every` must be >= 1 second" unless valid?
    end

    def to_s
      EVERY_KEYWORDS.to_a.reverse.each do |friendly, period|
        next unless @period % period == 0

        rem = @period / period

        return "#{rem} #{friendly}" if rem == 1
        return "#{rem} #{friendly}s"
      end

      "#{@period.to_i} second#{@period.to_i == 1 ? '' : 's'}"
    end

    private def valid?
      @period.to_f >= 1
    end

    def next_at(last = Time.now)
      last + @period
    end

    def self.parse(every)
      case every
      when Numeric, ActiveSupport::Duration
        new(every)
      when String, Symbol
        key = every.downcase.to_sym

        raise FailedToParse, every unless EVERY_KEYWORDS.key?(key)

        new(EVERY_KEYWORDS[key])
      else
        raise FailedToParse, every
      end
    end
  end
end
