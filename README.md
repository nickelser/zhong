# Zhong

Useful, reliable distributed cron.

# Installation

Add this line to your application’s Gemfile:

```ruby
gem 'zhong'
```

## Usage

```ruby
r = Redis.new

Zhong.schedule(redis: r) do |s|
  s.category "stuff" do
    s.every(5.seconds, "foo") { puts "foo" }
    s.every(1.week, "baz", at: "mon 22:45") { puts "baz" }
  end

  s.category "clutter" do
    s.every(1.second, "compute", if: -> (t) { rand < 0.5 }) { puts "something happened" }
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
