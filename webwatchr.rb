#!/usr/bin/ruby

require "fileutils"
require "json"
require "net/http"
require "net/smtp"
require "optparse"
require "timeout"

require_relative "lib/config"
require_relative "lib/logger"
require_relative "todo"

$: << "./lib/" # for telegram to load

trap("INT") do
  warn "User interrupted"
  exit
end

class Webwatchr
  include Loggable

  # Connects to a SMTP server to send an email
  #
  # ==== Arguments
  #
  # * +content+       - The content to send, as String
  # * +from+          - The From: email address to use, as String
  # * +to+            - The To: email address to use, as String
  # * +subject+       - The Subject: to use, as String
  # * +smtp_server+   - The smtp_server, as String
  # * +smtp_port+     - The smtp_port, as Fixnum
  #
  # ==== Examples
  #
  #    send_mail( content: "Update on this website",
  #                   from: "webwatchr@lol.lol",
  #                   to:   "me@lol.lol",
  #                   smtp_server: "localhost",
  #                   smtp_port: 25)
  #
  def send_mail(site:, from:, to:, smtp_server:, smtp_port:)
    raise StandardError, "Need to pass a Site instance" unless site

    subject = site.get_email_subject() || "Update from #{site.class}"

    formatted_content = site.get_html_content()

    msgstr = <<~END_OF_MESSAGE
      From: #{from}
      To: #{to}
      MIME-Version: 1.0
      Content-type: text/html; charset=UTF-8
      Subject: [Webwatchr] #{subject}

      Update from #{site.get_email_url()}

      #{formatted_content}
    END_OF_MESSAGE

    begin
      Net::SMTP.start(smtp_server, smtp_port, starttls: false) do |smtp|
        smtp.send_message(msgstr, from, to)
        logger.debug("Sending mail to #{to}")
      end
    rescue Net::SMTPFatalError => e
      logger.error "Couldn't send email from #{from} to #{to}. #{smtp_server}:#{smtp_port} said #{e.message}"
    end
  end

  def make_telegram_message_pieces(site:)
    unless site
      raise StandardError, "Need to pass a Site instance"
    end

    msg_pieces = []
    if site.content.instance_of?(Array)
      site.content.each do |item|
        line = item["title"]
        if item["url"]
          if line
            line += ": #{item['url']}"
          else
            line = item["url"]
          end

          line += ": #{item['url']}"
        end
        msg_pieces << line
      end
    else
      msg_pieces << site.content
    end
    return msg_pieces
  end

  def make_alerts(config)
    res_procs = {}
    config["default_alert"].each do |a|
      case a
      when "email"
        res_procs["email"] = proc { |args|
          args.delete(:name)
          args[:smtp_server] = config["alerts"]["email"]["smtp_server"]
          args[:smtp_port] = config["alerts"]["email"]["smtp_port"]
          args[:to] = config["alerts"]["email"]["dest_email"]
          args[:from] = config["alerts"]["email"]["from_email"]
          send_mail(**args)
        }
      when "telegram"
        begin
          require 'telegram/bot'
          res_procs["telegram"] = proc { |args|
            cid = config["alerts"]["telegram"]["chat_id"]
            bot = Telegram::Bot::Client.new(config["alerts"]["telegram"]["token"])
            title = args[:site].get_email_subject
            msg_pieces = [title]
            msg_pieces << args[:site].get_email_url()

            msg_pieces += make_telegram_message_pieces(site: args[:site])
            msg_pieces = msg_pieces.map { |x| x.size > 4096 ? x.split("\n") : x }.flatten()
            split_msg = msg_pieces.each_with_object(['']) { |str, sum|
              sum.last.length + str.length > 4000 ? sum << "#{str}\n" : sum.last << "#{str}\n"
            }

            split_msg.each do |m|
              bot.api.send_message(chat_id: cid, text: m)
            end
          }
        rescue LoadError
          puts "Please open README.md to see how to make Telegram alerting work"
        end
      else
        raise Exception("Unknown alert method : #{a}")
      end
    end
    return res_procs
  end

  def init(config)
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

    config["alert_procs"] = make_alerts(config)

    case config[:mode]
    when :single
      sites_to_run = SITES_TO_WATCH.select { |s|
        rb_file = File.basename(Object.const_source_location(s.class.name)[0])
        rb_file == config[:site]
      }
    when :normal
      sites_to_run = SITES_TO_WATCH
    else
      raise StandardError, "Unknown WebWatchr mode: #{config[:mode]}"
    end
    if sites_to_run.empty?
      warn "Didn't find any site to parse. edit todo.rb"
    end

    sites_to_run.each do |site_obj|
      logger.info "Running #{site_obj.name}"
      Timeout.timeout(config["site_timeout"]) {
        site_obj.test = config[:test]
        site_obj.update()
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
      msg = "Issue with #{site_obj} : #{e}\n"
      msg += "#{e.message}\n"
      logger.error msg
      msg += e.backtrace.join("\n")
      logger.debug e.backtrace.join("\n")
      warn msg
      raise e
    end
  end

  def main()
    options = { config: "config.json", mode: :normal , test: false, force: false}
    OptionParser.new { |o|
      o.banner = """WebWatchr is a script to poll websites and alert on changes.
  Exemple uses:
   * Updates all webpages according to their 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__}
   * Updates sites-available/site.rb, ignoring 'wait' value, and compare against internal state, and update it.
      ruby #{__FILE__} -s site.rb

  Usage: ruby #{__FILE__} """
      o.on("-sSITE", "--site=SITE", "Run WebWatcher on one site only. It has to be the name of a script in sites-enabled.") do |v|
        options[:site] = v
        options[:mode] = :single
      end
      o.on("-cCONF", "--config=CONF", "Use a specific config file (default: ./config.json") do |v|
        options[:config] = v
      end
      o.on("-v", "--verbose", "Be verbose (output to STDOUT instead of logfile") do
        options[:verbose] = true
      end
      o.on("-f", "--force", "Ignore waiting time between updates") do
        options[:force] = true
      end
      o.on("-t", "--test", "Check website and return what we've parsed") do
        options[:test] = true
      end
      o.on("-h", "--help", "Prints this help") {
        puts o
        exit
      }
    }.parse!

    config = nil

    if not File.exist?(options[:config])
      warn "Copy config.json.template to config.json and update it to your needs, or specify a config file with --config"
      exit
    else
      config = JSON.parse(File.read(options[:config]))
    end

    config[:verbose] = options[:verbose]
    config[:mode] = options[:mode]
    config[:site] = options[:site]
    config[:force] = options[:force]
    config[:test] = options[:test]

    Config.set_config(config)
    log_dir = config["log_dir"] || "logs"
    unless File.absolute_path?(log_dir)
      log_dir = File.join(File.absolute_path(Dir.getwd()), log_dir)
    end
    unless File.exist?(log_dir)
      FileUtils.mkdir_p(log_dir)
    end
    log_out_file = if config[:verbose]
                     $stdout
                   else
                     File.join(log_dir, 'webwatchr.log')
                   end
    log_out_file_rotation = 'weekly'
    log_level = $VERBOSE ? Logger::DEBUG : Logger::INFO

    MyLog.instance.configure(log_out_file, log_out_file_rotation, log_level)

    if File.exist?(config["pid_file"]) and not options[:site]
      logger.info "Already running. Quitting"
      exit
    end

    begin
      File.open(config["pid_file"], 'w+') { |f|
        f.puts($$)
        init(Config.config)
      }
    ensure
      if File.exist?(config["pid_file"])
        FileUtils.rm config["pid_file"]
      end
    end
    logger.info("Webwatcher finished working")
  end
end

w = Webwatchr.new()
w.main()
