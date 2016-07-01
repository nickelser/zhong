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
