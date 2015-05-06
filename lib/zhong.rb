require "logger"
require "redis"
require "suo"
require "active_support/time"

require "zhong/version"

require "zhong/util"

require "zhong/at"
require "zhong/every"

require "zhong/job"
require "zhong/scheduler"

module Zhong
  class << self
    def schedule(**opts)
      @scheduler = Scheduler.new(opts).tap do |s|
        yield(s)
      end
    end

    def start
      fail "You must run `Zhong.schedule` first" unless scheduler
      scheduler.start
    end

    def scheduler
      @scheduler
    end
  end
end
