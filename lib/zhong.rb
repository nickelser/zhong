require "logger"
require "redis"
require "suo"
require "active_support/time"

require "zhong/version"

require "zhong/at"
require "zhong/every"

require "zhong/job"
require "zhong/scheduler"

module Zhong
  class << self
    def schedule(**opts, &block)
      @scheduler = Scheduler.new(opts)
      @scheduler.instance_eval(&block)
      @scheduler.start
    end
  end
end
