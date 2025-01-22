require 'logger'
require 'singleton'

class MyLog
  include Singleton

  def initialize
    @many_loggers = {}
  end

  def logger(class_name)
    unless @many_loggers[class_name]
      @many_loggers[class_name] = Logger.new(@default_out, @default_rotation, level: @default_level)
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
