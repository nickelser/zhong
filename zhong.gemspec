# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "zhong/version"

Gem::Specification.new do |spec|
  spec.name          = "zhong"
  spec.version       = Zhong::VERSION
  spec.authors       = ["Nick Elser"]
  spec.email         = ["nick.elser@gmail.com"]

  spec.summary       = %q{Reliable, distributed cron.}
  spec.description   = %q{Reliable, distributed cron.}
  spec.homepage      = "https://www.github.com/nickelser/zhong"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.bindir        = "bin"
  spec.executables   = ["zhong"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.1"

  spec.add_dependency "suo"
  spec.add_dependency "redis"
  spec.add_dependency "tzinfo"
  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rubocop", "~> 0.30.0"
  spec.add_development_dependency "minitest", "~> 5.5.0"
  spec.add_development_dependency "codeclimate-test-reporter", "~> 0.4.7"
  spec.add_development_dependency "sinatra", "~> 1.4", ">= 1.4.6"
  spec.add_development_dependency "rack-test", "~> 0.6"
  spec.add_development_dependency "tilt"
  spec.add_development_dependency "erubis"
  spec.add_development_dependency "pry"
end
