require 'logger'
require 'singleton'

class MyLog
  include Singleton

  def initialize
    @many_loggers = {}
    @default_level = Logger::DEBUG
    @default_out = $stdout
  end

  def logger(class_name)
    unless @many_loggers[class_name]
      @many_loggers[class_name] = Logger.new(@default_out, @default_rotation, level: @default_level, progname: class_name)
    end
    return @many_loggers[class_name]
  end

  def configure(out, rotation, level)
    @default_out = out
    @default_rotation = rotation
    @default_level = level
  end
end

module Loggable
  def logger
    MyLog.instance.logger(self.class.name)
  end
end
