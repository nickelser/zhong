# Zhong

Useful, reliable distributed cron. Tired of your cron-like scheduler running key jobs twice? Would you like to be able to run your cron server on multiple machines and have it "just work"? Have we got the gem for you.

Zhong uses Redis to acquire exclusive locks on jobs, as well as recording when they last ran. This means that you can rest easy at night, knowing that your customers are getting their monthly Goat Fancy magazine subscriptions and you are rolling around in your piles of money without a care in the world.

# Installation

Add this line to your application’s Gemfile:

```ruby
gem 'zhong'
```

## Usage

```ruby
Zhong.redis = Redis.new(ENV["ZHONG_REDIS_URL"])

Zhong.schedule do
  category "stuff" do
    every 5.seconds, "foo" do
      puts "foo"
    end

    every(1.minute, "biz", at: ["**:26", "**:27"]) { puts "biz" }
    every(1.week, "baz", at: ["mon 22:45", "wed 23:13"]) { puts "baz" }
    every(10.seconds, "boom") { raise "fail" }
  end

  category "clutter" do
    every(1.second, "compute", if: -> (t) { t.wday == 3 && rand < 0.5 }) do
      puts "something happened on wednesday, maybe"
    end
  end

  # note: callbacks that return nil or false will cause event to not run
  on(:before_tick) do
    puts "ding"
    true
  end

  on(:after_tick) do
    puts "dong"
    true
  end

  error_handler do |e, job|
    puts "damn, #{job} messed up: #{e}"
  end
end
```

## TODO
 - better logging
 - error handling
 - tests
 - examples
 - callbacks
 - generic handler

## History

View the [changelog](https://github.com/nickelser/zhong/blob/master/CHANGELOG.md).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/nickelser/zhong/issues)
- Fix bugs and [submit pull requests](https://github.com/nickelser/zhong/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
