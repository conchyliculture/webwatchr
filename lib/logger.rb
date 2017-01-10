#!/usr/bin/ruby
# encoding: utf-8

class MyLogger
    require "logger"
    def initialize(logfile: STDERR)
        @logger = Logger.new(logfile)
    end

    def err(msg)
        @logger.error Colors.red(msg)
    end

    def warn(msg)
        @logger.warn Colors.yellow(msg)
    end

    def info(msg)
        @logger.info Colors.blue(msg)
    end

    def debug(msg)
        @logger.info Colors.grey(msg)
    end

    def success(msg)
        @logger.info Colors.green(msg)
    end
end

