#!/usr/bin/ruby

require "optparse"

require_relative "logger"

$: << "./lib/" # for telegram to load

trap("INT") do
  warn "User interrupted"
  exit
end

module Webwatchr
  include Loggable

  PARAMS = { mode: :normal, test: false } # rubocop:disable Style/MutableConstant

  if ARGV.any?
    OptionParser.new { |o|
      o.banner = "WebWatchr is a script to poll websites and alert on changes.
  Exemple uses:
   * Updates all webpages according to their 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__}
   * Updates sites-available/site.rb, ignoring 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__} -s site.rb

  Usage: ruby #{__FILE__} "
      o.on("-sSITE", "--site=SITE", "Run WebWatcher on one site only. It has to be the name of the class for that site.") do |val|
        PARAMS[:site] = val
        PARAMS[:mode] = :single
      end
      o.on("-v", "--verbose", "Be verbose (output to STDOUT instead of logfile") do
        PARAMS[:verbose] = true
      end
      o.on("-t", "--test", "Check website and return what we've parsed") do
        PARAMS[:test] = true
      end
      o.on("-h", "--help", "Prints this help") {
        puts o
        exit
      }
    }.parse!()
  end

  PARAMS[:cache_dir] = File.join(__dir__, "..", "..", ".cache")
  PARAMS[:last_dir] = File.join(__dir__, "..", "..", ".lasts")
  PARAMS[:log_dir] = File.join(__dir__, "..", "..", "logs")
  PARAMS[:pid_file] = File.join(__dir__, "..", "..", "webwatchr.pid")
  require "webwatchr/base"
end
