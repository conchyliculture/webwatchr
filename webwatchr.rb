#!/usr/bin/ruby

$: << "lib"

require "fileutils"
require "json"
require "logger"
require "net/http"
require "net/smtp"
require "optparse"
require "timeout"


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
def send_mail(content: , from: , to:, subject: , smtp_server: , smtp_port:)

    msgstr = <<END_OF_MESSAGE
From: #{from}
To: #{to}
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
Subject: #{subject}

#{content}
END_OF_MESSAGE

    begin
        Net::SMTP.start(smtp_server, smtp_port) do |smtp|
            smtp.send_message(msgstr, from, to)
            $logger.debug("Sending mail to #{to}")
        end
    rescue Net::SMTPFatalError => e
        $logger.error "Couldn't send email from #{from} to #{to}. #{smtp_server}:#{smtp_port} said #{e.message}"
    end
end

def make_alerts(c)
    res_procs = []
    c["default_alert"].each do |a|
        case a
        when "email"
            res_procs.append(Proc.new { |args|
                unless args[:subject]
                    args[:subject] = "[Webwatchr] Site #{args[:name]} updated"
                end
                args.delete(:name)
                args[:smtp_server] = $CONF["alerts"]["email"]["smtp_server"]
                args[:smtp_port] = $CONF["alerts"]["email"]["smtp_port"]
                args[:to] = $CONF["alerts"]["email"]["dest_email"]
                args[:from] = $CONF["alerts"]["email"]["from_email"]
                send_mail(args)
            })
        when "rss"
            res_procs.append(Proc.new { |args|
    #            gen_rss(args)
            })
        when "telegram"
            begin
              require 'telegram/bot'
              res_procs.append(Proc.new { |args|
                bot = Telegram::Bot::Client.new($CONF["alert"]["telegram"]["token"])
                bot.api.send_message(chat_id: $CONF["alert"]["telegram"]["chat_id"], text: args[:content])
              })
            rescue LoadError
                puts "Please open README.md to see how to make Telegram alerting work"
            end
        else
            raise Exception("Unknown alert method : #{a}")
        end
    end
    return res_proc
end

def init(options)
    $logger.debug("Starting WebWatchr")

    $MYDIR = File.dirname(__FILE__)

    unless $CONF["last_dir"]
        $CONF["last_dir"] = File.join($MYDIR, ".lasts")
    end
    FileUtils.mkdir_p($CONF["last_dir"])
    FileUtils.mkdir_p(File.join($MYDIR, "sites-enabled"))

    timeout = $CONF["site_timeout"]
    $CONF["alert_procs"] = make_alerts($CONF)
    if options[:site]
        site = File.join("sites-available", options[:site])
        load_site(site, timeout)
    else
        sites = Dir.glob(File.join($MYDIR, "sites-enabled", "*.rb"))
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

    options = {}
    OptionParser.new { |o|
        o.banner = """WebWatchr is a script to poll websites and alert on changes.
Exemple uses:
 * Updates all webpages according to their 'wait' value, and compare against internal state, and update it.
    ruby #{__FILE__}
 * Updates sites-available/site.rb, ignoring 'wait' value, and compare against internal state, and update it.
    ruby #{__FILE__} -s site.rb

Usage: ruby #{__FILE__} """
        o.on("-sSITE", "--site=SITE", "Run WebWatcher on one site only. It has to be the name of a script in sites-available.") do |v|
            options[:site] = v
        end
        o.on("-h", "--help", "Prints this help"){puts o; exit}
    }.parse!

    if File.exist?($CONF["pid_file"]) and not options[:site]
        $logger.info "Already running. Quitting"
        exit
    end

    begin
        File.open($CONF["pid_file"],'w+') {|f|
            f.puts($$)
            init(options)
        }
    ensure
        if File.exist?($CONF["pid_file"])
            FileUtils.rm $CONF["pid_file"]
        end
    end
    $logger.info("Webwatcher finished working")
end

if not File.exist?("config.json")
    $stderr.puts "Copy config.json.template to config.json and update it to your needs"
    exit
else
    $CONF=JSON.parse(File.read("config.json"))
end

$logger = Logger.new($CONF["log"] || STDOUT)
$logger.level = $VERBOSE ? Logger::DEBUG : Logger::INFO

main()
