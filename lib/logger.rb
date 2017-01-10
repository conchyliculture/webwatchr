#!/usr/bin/ruby
# encoding: utf-8

require "logger"

module Colors
    GREY="\033[1;30m"
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    PURPLE="\033[1;35m"
    TEAL="\033[1;36m"
    WHITE="\033[1;37m"

    NORM="\033[0m"

    def Colors.norm()
        return NORM
    end
    
    def Colors.grey(s)
        return GREY+s.to_s+NORM
    end
    def Colors.green(s)
        return GREEN+s.to_s+NORM
    end
    def Colors.red(s)
        return RED+s.to_s+NORM
    end
    def Colors.yellow(s)
        return YELLOW+s.to_s+NORM
    end
    def Colors.blue(s)
        return BLUE+s.to_s+NORM
    end
    def Colors.purple(s)
        return PURPLE+s.to_s+NORM
    end
    def Colors.teal(s)
        return TEAL+s.to_s+NORM
    end
    def Colors.white(s)
        return WHITE+s.to_s+NORM
    end
end

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

