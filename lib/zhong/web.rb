# frozen_string_literal: true
require "erb"
require "sinatra/base"

require "zhong"
require "zhong/web_helpers"

module Zhong
  # Most of the following helpers are copied from a previous version of the Sidekiq project
  # available here: https://github.com/mperham/sidekiq/blob/2c9f7662fcdcb52d59b72ba0fe7dc5f963de4904/lib/sidekiq/web.rb
  class Web < Sinatra::Base
    enable :sessions
    use ::Rack::Protection, use: :authenticity_token unless ENV["RACK_ENV"] == "test"

    if ENV["ZHONG_WEB_USERNAME"] && ENV["ZHONG_WEB_PASSWORD"]
      # :nocov:
      use Rack::Auth::Basic, "Sorry." do |username, password|
        username == ENV["ZHONG_WEB_USERNAME"] and password == ENV["ZHONG_WEB_PASSWORD"]
      end
      # :nocov:
    end

    if ENV["RACK_ENV"] == "development"
      # :nocov:
      before do
        STDERR.puts "[params] #{params}" unless params.empty?
      end
      # :nocov:
    end

    set :root, File.expand_path(File.dirname(__FILE__) + "/../../web")
    set :public_folder, proc { "#{root}/assets" }
    set :views, proc { "#{root}/views" }

    helpers WebHelpers

    get "/" do
      index

      erb :index
    end

    post "/" do
      if params["disable"]
        job = Zhong.jobs[params["disable"]]

        job.disable if job
      elsif params["enable"]
        job = Zhong.jobs[params["enable"]]

        job.enable if job
      end

      index

      erb :index
    end

    def index
      @jobs = Zhong.jobs.values
      @last_runs = zhong_mget(@jobs, "last_ran")
      @disabled = zhong_mget(@jobs, "disabled")
      @hosts = Zhong.all_heartbeats
    end

    def zhong_mget(jobs, key)
      keys = jobs.map(&:to_s)
      ret = Zhong::Util.safe_mget(keys.map { |j| "zhong:#{key}:#{j}" })
      Hash[keys.map { |j| [j, ret["zhong:#{key}:#{j}"]] }]
    end
  end
end

if defined?(::ActionDispatch::Request::Session) && !::ActionDispatch::Request::Session.respond_to?(:each)
  # mperham/sidekiq#2460
  # Rack apps can't reuse the Rails session store without
  # this monkeypatch
  class ActionDispatch::Request::Session
    # :nocov:
    def each(&block)
      hash = self.to_hash
      hash.each(&block)
    end
    # :nocov:
  end
end
