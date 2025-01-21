require "logger"

class MyLogger
  def initialize(logfile: $stderr)
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
