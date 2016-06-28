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

    if ENV["RACK_ENV"] == "development"
      before do
        STDERR.puts "[params] #{params}" unless params.empty?
      end
    end

    set :root, File.expand_path(File.dirname(__FILE__) + "/../../web")
    set :public_folder, proc { "#{root}/assets" }
    set :views, proc { "#{root}/views" }

    helpers WebHelpers

    get '/' do
      index

      erb :index
    end

    post '/' do
      if params['disable']
        if job = Zhong.jobs[params['disable']]
          job.disable
        end
      elsif params['enable']
        if job = Zhong.jobs[params['enable']]
          job.enable
        end
      end

      index

      erb :index
    end

    def index
      @jobs = Zhong.jobs.values
      @last_runs = zhong_mget(@jobs, "last_ran")
      @disabled = zhong_mget(@jobs, "disabled")
      @hosts = safe_mget(Zhong.redis.scan_each(match: "zhong:heartbeat:*").to_a).map do |k, v|
        host, pid = k.split("zhong:heartbeat:", 2)[1].split("#", 2)
        {host: host, pid: pid, last_seen: Time.at(v.to_i)}
      end
    end

    def zhong_mget(jobs, key)
      keys = jobs.map(&:to_s)
      ret = safe_mget(keys.map { |j| "zhong:#{key}:#{j}" })
      Hash[keys.map { |j| [j, ret["zhong:#{key}:#{j}"]] }]
    end

    def safe_mget(keys)
      if keys.length > 0
        Zhong.redis.mapped_mget(*keys)
      else
        {}
      end
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
