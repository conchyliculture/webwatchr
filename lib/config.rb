require "singleton"

class Config
  include Singleton
  def self.config
    return @c
  end

  def self.set_config(args)
    @c = args
  end
end
