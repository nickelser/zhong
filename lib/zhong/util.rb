module Zhong
  module Util
    class << self
      def default_logger
        Logger.new(STDOUT).tap do |logger|
          logger.formatter = -> (_, datetime, _, msg) { "#{datetime}: #{msg}\n" }
        end
      end
    end
  end
end
