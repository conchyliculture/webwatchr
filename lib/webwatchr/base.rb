module Webwatchr
  require_relative "alerting"
  class Main
    include Loggable

    def initialize(&block)
      @alerts = []
      super()
      setup_logs
      run!
      instance_eval(&block)
      logger.info("Webwatcher finished working")
    end

    def running?
      return (File.exist?(config["pid_file"]) and not PARAMS[:site])
    end

    def setup_logs
      log_dir = config["log_dir"] || "logs"
      unless File.absolute_path?(log_dir)
        log_dir = File.join(File.absolute_path(Dir.getwd()), log_dir)
      end
      unless File.exist?(log_dir)
        FileUtils.mkdir_p(log_dir)
      end
      log_out_file = if PARAMS[:verbose] || PARAMS[:test]
                       $stdout
                     else
                       File.join(log_dir, 'webwatchr.log')
                     end
      log_out_file_rotation = 'weekly'
      log_level = $VERBOSE ? Logger::DEBUG : Logger::INFO

      MyLog.instance.configure(log_out_file, log_out_file_rotation, log_level)
    end

    def config
      PARAMS[:config]
    end

    def init()
      logger.debug("Starting WebWatchr")

      current_dir = File.dirname(__FILE__)

      unless config["last_dir"]
        config["last_dir"] = File.join(current_dir, ".lasts")
      end
      unless config["cache_dir"]
        config["cache_dir"] = File.join(current_dir, ".cache")
      end
      FileUtils.mkdir_p(config["last_dir"])
      FileUtils.mkdir_p(config["cache_dir"])

      Dir[File.join(__dir__, '..', 'sites', '*.rb')].sort.each do |site_path|
        logger.debug("Loading #{site_path}")
        require site_path
      end
    end

    def update(site_class, &block)
      site = site_class.create(&block)
      site.alerters = @alerts
      logger.info "Running #{site.name}"
      site.instance_eval(&block)
      Timeout.timeout(config["site_timeout"]) {
        #        site.config = config
        site.update(test: PARAMS[:test])
      }
    rescue Net::OpenTimeout, Errno::ENETUNREACH, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Zlib::BufError, Errno::ECONNREFUSED, SocketError, Net::ReadTimeout => e
      logger.warn "Failed pulling #{site}: #{e.message}"
      # Do nothing, try later
    rescue SystemExit => e
      msg = "User requested we quit while updating #{site}\n"
      logger.error msg
      warn msg
      raise e
    rescue StandardError => e
      msg = "Issue with #{site} : #{e}\n"
      msg += "#{e.message}\n"
      logger.error msg
      msg += e.backtrace.join("\n")
      logger.debug e.backtrace.join("\n")
      warn msg
      raise e
    end

    def run!
      if running?
        logger.info "Already running. Quitting"
        exit
      end

      begin
        File.open(config["pid_file"], 'w+') { |f|
          f.puts($$)
          init()
        }
      ensure
        if File.exist?(config["pid_file"])
          FileUtils.rm config["pid_file"]
        end
      end
    end

    def add_default_alert(type, &block)
      case type
      when :email
        alert = Alerting::EmailAlert.create(&block)
        @alerts.append(alert)
      when :telegram
        alert = Alerting::TelegramAlert.create(&block)
        @alerts.append(alert)
      else
        raise StandardError, "Unknown alert type: #{type}."
      end
    end
  end
end
