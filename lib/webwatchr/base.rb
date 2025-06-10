require "fileutils"

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
      return (File.exist?(PARAMS[:pid_file]) and not PARAMS[:site])
    end

    def set(key, val)
      PARAMS[key] = val
      self
    end

    def setup_logs
      FileUtils.mkdir_p(PARAMS[:log_dir])
      log_out_file = if PARAMS[:verbose] || PARAMS[:test]
                       $stdout
                     else
                       File.join(PARAMS[:log_dir], 'webwatchr.log')
                     end
      log_out_file_rotation = 'weekly'
      log_level = $VERBOSE ? Logger::DEBUG : Logger::INFO

      MyLog.instance.configure(log_out_file, log_out_file_rotation, log_level)
    end

    def init()
      logger.debug("Starting WebWatchr")

      FileUtils.mkdir_p(PARAMS[:last_dir])
      FileUtils.mkdir_p(PARAMS[:cache_dir])

      Dir[File.join(__dir__, '..', 'sites', '*.rb')].sort.each do |site_path|
        logger.debug("Loading #{site_path}")
        require site_path
      end
    end

    def update(site_class, &block)
      if (PARAMS[:mode] == :single) && site_class.to_s != PARAMS[:site]
        logger.info("Running in single site mode, skipping #{site_class} (!= #{PARAMS[:site]})")
        return
      end

      site = site_class.create(&block)

      site.alerters = @alerts

      logger.info "Running #{site.name}"
      if block
        site.instance_eval(&block)
      end
      Timeout.timeout(PARAMS[:site_timeout]) {
        site.update(test: PARAMS[:test], cache_dir: PARAMS[:cache_dir], last_dir: PARAMS[:last_dir])
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
      msg = "Issue with #{site_class} : #{e}\n"
      msg += "#{e.message}\n"
      logger.error msg
      msg += e.backtrace.join("\n")
      logger.debug e.backtrace.join("\n")
      warn msg
    end

    def run!
      if running?
        logger.info "Already running. Quitting"
        exit
      end

      begin
        File.open(PARAMS[:pid_file], 'w+') { |f|
          f.puts($$)
          init()
        }
      ensure
        if File.exist?(PARAMS[:pid_file])
          FileUtils.rm PARAMS[:pid_file]
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
      when :stdout
        alert = Alerting::StdoutAlert.create()
        @alerts.append(alert)
      else
        raise StandardError, "Unknown alert type: #{type}."
      end
    end
  end
end
