# frozen_string_literal: true
require "erb"
require "sinatra/base"

require "zhong"
require "zhong/web_helpers"

module Zhong
  class Web < Sinatra::Base
    enable :sessions
    use ::Rack::Protection, use: :authenticity_token unless ENV["RACK_ENV"] == "test"

    if ENV["ZHONG_WEB_USERNAME"] && ENV["ZHONG_WEB_PASSWORD"]
      use Rack::Auth::Basic, "Sorry." do |username, password|
        username == ENV["ZHONG_WEB_USERNAME"] and password == ENV["ZHONG_WEB_PASSWORD"]
      end
    end

    set :root, File.expand_path(File.dirname(__FILE__) + "/../../web")
    set :public_folder, proc { "#{root}/assets" }
    set :views, proc { "#{root}/views" }

    helpers WebHelpers

    get '/' do
      @jobs = Zhong.jobs
      @last_runs = mget(@jobs, "last_ran")
      @disabled = mget(@jobs, "disabled")

      Rails.logger.info @last_runs

      erb :index
    end

  end
end

if defined?(::ActionDispatch::Request::Session) &&
    !::ActionDispatch::Request::Session.respond_to?(:each)
  # mperham/sidekiq#2460
  # Rack apps can't reuse the Rails session store without
  # this monkeypatch
  class ActionDispatch::Request::Session
    def each(&block)
      hash = self.to_hash
      hash.each(&block)
    end
  end
end
