# Zhong [![Build Status](https://github.com/nickelser/zhong/workflows/CI/badge.svg)](https://github.com/nickelser/zhong/actions?query=workflow%3ACI) [![Code Climate](https://codeclimate.com/github/nickelser/zhong/badges/gpa.svg)](https://codeclimate.com/github/nickelser/zhong) [![Gem Version](https://badge.fury.io/rb/zhong.svg)](http://badge.fury.io/rb/zhong)

Useful, reliable distributed cron. Tired of your cron-like scheduler running key jobs twice? Would you like to be able to run your cron server on multiple machines and have it "just work"? Have we got the gem for you.

Zhong uses Redis to acquire exclusive locks on jobs, as well as recording when they last ran. This means that you can rest easy at night, knowing that your customers are getting their monthly Goat Fancy magazine subscriptions and you are rolling around in your piles of money without a care in the world.

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)
# Installation

Add this line to your application’s Gemfile:

```ruby
gem 'zhong'
```

## Usage

### Zhong schedule
Create a definition file, let's call it `zhong.rb`:

```ruby
Zhong.redis = Redis.new(url: ENV["ZHONG_REDIS_URL"])

Zhong.schedule do
  category "stuff" do
    every 5.seconds, "foo" do
      puts "foo"
    end

    every(1.minute, "running biz at 26th and 27th minute", at: ["**:26", "**:27"]) { puts "biz" }
    every(1.week, "running baz on mon and wed", at: ["mon 22:45", "wed 23:13"]) { puts "baz" }
    every(10.seconds, "boom every 10 seconds") { raise "fail" }
  end

  category "clutter" do
    every(1.second, "compute", if: -> (t) { t.wday == 3 && rand < 0.5 }) do
      puts "something happened on wednesday, maybe"
    end
  end

  # note: callbacks that explicitly false will cause event to not run
  on(:before_tick) do
    puts "ding"
    true
  end

  on(:after_tick) do
    puts "dong"
  end

  on(:before_run) do |job, time|
    puts "running #{job}"
    true # can conditionally run a specific job
  end

  on(:after_run) do |job, time, ran|
    puts "#{job} ran?: #{ran}"
  end

  on(:before_disable) do |job|
    puts "#{job} is going to be disabled"
  end

  on(:after_disable) do |job|
    puts "#{job} disabled"
  end

  on(:before_enable) do |job|
    puts "#{job} is going to be enabled"
  end

  on(:after_enable) do |job|
    puts "#{job} enabled"
  end

  error_handler do |e, job|
    puts "dang, #{job} messed up: #{e}"
  end
end
```

This file only describes what should be the schedule. Nothing will be executed
until we actually run
```ruby
Zhong.start
```
after describing the Zhong schedule.

### Zhong cron process

You can run the cron process that will execute your code from the definitions
in the `zhong.rb` file by running:
```sh
zhong zhong.rb
```

## Web UI

Zhong comes with a web application that can display jobs, their last run and
enable/disable them.

This is a Sinatra application that requires at least `v2.0.0`. You can add to your Gemfile
```ruby
gem 'sinatra', "~>2.0"
```

It can be protected by HTTP basic authentication by
setting the following environment variables:
- `ZHONG_WEB_USERNAME`: the username
- `ZHONG_WEB_PASSWORD`: the password

You'll need to load the Zhong schedule to be able to see jobs in the web UI, typically
by requiring your `zhong.rb` definition file.

### Rails
Load the Zhong schedule by creating an initializer at `config/initializers/zhong.rb`,
with the following content:
```ruby
require "#{Rails.root}/zhong.rb"
```

Add the following to your `config/routes.rb`:
```ruby
require 'zhong/web'

Rails.application.routes.draw do
  # Other routes here...

  mount Zhong::Web, at: "/zhong"
end
```

## Build

### Dependecies

  - bundle 2.2.0 or major
  - docker and docker-compose 2 or major
  - ruby 2.7 or major
### Run

 - bundle install
 - docker-compose up -d redis

#### Run tests
 
  - ruby test/test_*.rb

## History

View the [changelog](https://github.com/nickelser/zhong/blob/master/CHANGELOG.md).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/nickelser/zhong/issues)
- Fix bugs and [submit pull requests](https://github.com/nickelser/zhong/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
