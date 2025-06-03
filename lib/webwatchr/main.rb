#!/usr/bin/ruby

require "fileutils"
require "json"
require "net/http"
require "net/smtp"
require "optparse"
require "timeout"

require_relative "logger"

$: << "./lib/" # for telegram to load

trap("INT") do
  warn "User interrupted"
  exit
end

module Webwatchr
  include Loggable

  PARAMS = { config_file: "config.json", mode: :normal, test: false } # rubocop:disable Style/MutableConstant

  if ARGV.any?
    OptionParser.new { |o|
      o.banner = "WebWatchr is a script to poll websites and alert on changes.
  Exemple uses:
   * Updates all webpages according to their 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__}
   * Updates sites-available/site.rb, ignoring 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__} -s site.rb

  Usage: ruby #{__FILE__} "
      o.on("-cCONF", "--config=CONF", "Use a specific config file (default: ./config.json") do |val|
        if File.exist?(val)
          PARAMS[:config] = JSON.parse(File.read(val))
        else
          raise StandardError, "Unable to find config file #{val}"
        end
      end
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
    }.parse!(into: PARAMS)
  end

  unless File.exist?(PARAMS[:config_file])
    warn "Copy config.json.template to config.json and update it to your needs, or specify a config file with --config"
    exit
  end
  PARAMS[:config] = JSON.parse(File.read(PARAMS[:config_file]))

  require "webwatchr/base"
end
