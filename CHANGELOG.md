## 0.2.4

- Compatibility with Sinatra/Tilt (thank you Brian Storti!)

## 0.2.3

- Much improved documentation, and executable file naming (thank you Antoine Augusti!)
- Fixes to the time parsing & to_s (thank you Antoine Augusti!)

## 0.2.2

- Re-licensed as LGPL, as I lifted Sidekiq-web code to power Zhong web (thanks Mike Perham for the great gem and the code!)

## 0.2.1

- Fix manually specifying a Redis connection (thanks, Richard Adams!)

## 0.2.0

- Configuring Redis and the heartbeat key now correctly updates even after Zhong is configured initially.
- Some cleanup in how config is stored in general.

## 0.1.9

- Much more performant heartbeat checks (thanks, @sherinkurian).

## 0.1.8

- Make it very clear when callbacks cause skips of ticks or runs.
- Add logging when jobs/ticks are skipped.
- Do not skip when callbacks return nil (only on false explicitly).

## 0.1.7

- Improve test coverage.
- Fix a small serialization issue.

## 0.1.6

- Add Zhong.any_running? for monitoring that any Zhong node has checked in rencently
- More code cleanup/refactoring.

## 0.1.5

- Improve the API.
- Add scheduler test.
- Add Zhong::Web to see job status, and enable/disable jobs. Activate it with:
    Rails.application.routes.draw do
      # ...
      require "zhong/web"
      mount Zhong::Web => "/zhong" # or wherever

## 0.1.4

- Fix several bugs related to time parsing.
- In a totally unrelated change, add some tests around time parsing.

## 0.1.3

- Fix several memory leaks.
- Add a proper error handler block.

## 0.1.2

- Fix bug with setting `at` like "**:35".

## 0.1.1

- Handle multiple `at`s (at: ["mon 8:00, tues 9:30"]).
- Job callbacks (:before_tick, :after_tick, etc).

## 0.1.0

- First release.
