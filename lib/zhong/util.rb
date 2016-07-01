module Zhong
  module Util
    def safe_mget(keys)
      if keys.empty?
        {}
      else
        Zhong.redis.mapped_mget(*keys)
      end
    end

    module_function :safe_mget
  end
end
