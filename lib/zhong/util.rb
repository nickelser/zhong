require "digest"

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

    # Avoid timming attacks
    # Based on: https://thisdata.com/blog/timing-attacks-against-string-comparison/
    def safe_compare(a, b)
      a = ::Digest::SHA256.hexdigest(a)
      b = ::Digest::SHA256.hexdigest(b)

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
    module_function :safe_compare

  end
end
