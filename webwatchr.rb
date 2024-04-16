#!/usr/bin/ruby

$: << "lib"

require "fileutils"
require "json"
require "logger"
require "net/http"
require "net/smtp"
require "optparse"
require "timeout"

require "config.rb"

trap("INT") do
    $stderr.puts "User interrupted"
    exit
end

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
def send_mail(site:, from: , to:, smtp_server: , smtp_port:)
  if not site
    raise Exception.new("Need to pass a Site instance")
  end

  subject = site.get_email_subject() || "Update from #{site.class}"

  formatted_content = site.get_formatted_content()

    msgstr = <<END_OF_MESSAGE
From: #{from}
To: #{to}
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
Subject: #{subject}

#{formatted_content}
END_OF_MESSAGE

    begin
        Net::SMTP.start(smtp_server, smtp_port, starttls: false) do |smtp|
            smtp.send_message(msgstr, from, to)
            $logger.debug("Sending mail to #{to}")
        end
    rescue Net::SMTPFatalError => e
        $logger.error "Couldn't send email from #{from} to #{to}. #{smtp_server}:#{smtp_port} said #{e.message}"
    end
end

def make_telegram_message_pieces(site:)
  if not site
    raise Exception.new("Need to pass a Site instance")
  end
  msg_pieces = []
  if args[:site].content.class == Array
    args[:site].content.each do |item|
        line = item["title"]
          if item["url"]
            if line
              line += ": "+item["url"]
            else
              line = item["url"]
            end

            line += ": "+item["url"]
          end
          msg_pieces << line
      end
  else
    msg_pieces << args[:site].content
  end
  return msg_pieces

end

def make_alerts(c)
    res_procs = {}
    c["default_alert"].each do |a|
        case a
        when "email"
            res_procs["email"] = Proc.new { |args|
                unless args[:subject]
                    args[:subject] = "[Webwatchr] Site #{args[:name]} updated"
                    args[:subject] += " (#{args[:comment]})" if args[:comment]
                end
                args.delete(:name)
                args[:smtp_server] = c["alerts"]["email"]["smtp_server"]
                args[:smtp_port] = c["alerts"]["email"]["smtp_port"]
                args[:to] = c["alerts"]["email"]["dest_email"]
                args[:from] = c["alerts"]["email"]["from_email"]
                send_mail(**args)
            }
        when "telegram"
            begin
              require 'telegram/bot'
              res_procs["telegram"] = Proc.new { |args|
                cid = c["alerts"]["telegram"]["chat_id"]
                bot = Telegram::Bot::Client.new(c["alerts"]["telegram"]["token"])
                title = args[:site].get_email_subject
                msg_pieces = [title]
                msg_pieces << make_telegram_message_pieces(site: args[:site])
                msg_pieces = msg_pieces.map{|x| x.size > 4096?  x.split("\n") : x}.flatten()
                split_msg = msg_pieces.inject(['']) { |sum, str| sum.last.length + str.length > 4000 ? sum << str +"\n" : sum.last << str+"\n" ; sum }

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

def init(config, site: nil)
    $logger.debug("Starting WebWatchr")

    current_dir = File.dirname(__FILE__)

    unless config["last_dir"]
        config["last_dir"] = File.join(current_dir, ".lasts")
    end
    FileUtils.mkdir_p(config["last_dir"])
    FileUtils.mkdir_p(File.join(current_dir, "sites-enabled"))

    timeout = config["site_timeout"]
    config["alert_procs"] = make_alerts(config)
    if site
        site_rb = File.join("sites-enabled", site)
        load_site(site_rb, timeout)
    else
        sites = Dir.glob(File.join(current_dir, "sites-enabled", "*.rb"))
        if sites.empty?
            $stderr.puts "Didn't find any site to parse. You might want to:"
            $stderr.puts "cd sites-enabled/ ; ln -s ../sites-available/something.rb . "
        end
        sites.each {|s| load_site(s, timeout)}
    end
end

def load_site(site, timeout=10*60)
    unless File.exist?(site)
        raise "Can't find site to load #{File.realpath(site)}"
    end
    begin
        $logger.info "loading #{File.basename(site)} file"
        Timeout::timeout(timeout) {
            load site
        }
    rescue Net::OpenTimeout, Errno::ENETUNREACH, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Zlib::BufError, Errno::ECONNREFUSED, SocketError, Net::ReadTimeout => e
        $logger.warn "Failed pulling #{site}: #{e.message}"
        # Do nothing, try later
    rescue Exception => e
        msg = "Issue with #{site} : #{e}\n"
        msg += "#{e.message}\n"
        $logger.error msg
        msg += e.backtrace.join("\n")
        $logger.debug e.backtrace.join("\n")
        $stderr.puts msg
    end
end

def main()
    options = {config: "config.json"}
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
        end
        o.on("-cCONF", "--config=CONF", "Use a specific config file (default: ./config.json") do |v|
            options[:config] = v
        end
        o.on("-h", "--help", "Prints this help"){puts o; exit}
    }.parse!

    config = nil

    if not File.exist?(options[:config])
        $stderr.puts "Copy config.json.template to config.json and update it to your needs, or specify a config file with --config"
        exit
    else
        config = JSON.parse(File.read(options[:config]))
    end
    Config.set_config(config)
    $logger = Logger.new(config["log"] || STDOUT)
    $logger.level = $VERBOSE ? Logger::DEBUG : Logger::INFO

    if File.exist?(config["pid_file"]) and not options[:site]
        $logger.info "Already running. Quitting"
        exit
    end

    begin
        File.open(config["pid_file"],'w+') {|f|
            f.puts($$)
            init(Config.config, site:options[:site])
        }
    ensure
        if File.exist?(config["pid_file"])
            FileUtils.rm config["pid_file"]
        end
    end
    $logger.info("Webwatcher finished working")
end

main()
