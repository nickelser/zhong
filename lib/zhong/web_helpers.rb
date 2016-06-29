# frozen_string_literal: true
require "uri"

module Zhong
  module WebHelpers
    # Simple capture method for erb templates. The origin was
    # capture method from sinatra-contrib library.
    def capture(&block)
      block.call
      eval("", block.binding)
    end

    def root_path
      "#{env['SCRIPT_NAME']}/"
    end

    def current_path
      @current_path ||= request.path_info.gsub(%r(^\/),"")
    end

    def relative_time(time)
      if time
        %(<time datetime="#{time.getutc.iso8601}">#{time}</time>)
      else
        "never"
      end
    end

    def truncate(text, truncate_after_chars = 2000)
      truncate_after_chars && text.size > truncate_after_chars ? "#{text[0..truncate_after_chars]}..." : text
    end

    def display_args(args, truncate_after_chars = 2000)
      args.map do |arg|
        h(truncate(to_display(arg), truncate_after_chars))
      end.join(", ")
    end

    def csrf_tag
      "<input type='hidden' name='authenticity_token' value='#{session[:csrf]}'/>"
    end

    def to_display(arg)
      arg.inspect
    rescue
      begin
        arg.to_s
      rescue => ex
        "Cannot display argument: [#{ex.class.name}] #{ex.message}"
      end
    end

    def number_with_delimiter(number)
      begin
        Float(number)
      rescue ArgumentError, TypeError
        return number
      end

      options = {delimiter: ",", separator: "."}
      parts = number.to_s.to_str.split(".")
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")
      parts.join(options[:separator])
    end

    def h(text)
      ::Rack::Utils.escape_html(text)
    rescue ArgumentError => e
      raise unless e.message.eql?("invalid byte sequence in UTF-8")
      text.encode!("UTF-16", "UTF-8", invalid: :replace, replace: "").encode!("UTF-8", "UTF-16")
      retry
    end

    def environment_title_prefix
      environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

      "[#{environment.upcase}] " unless environment == "production"
    end

    def product_version
      "Zhong v#{Zhong::VERSION}"
    end
  end
end
