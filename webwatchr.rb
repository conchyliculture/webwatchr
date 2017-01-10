#!/usr/bin/ruby

require "fileutils"
require "json"
require "net/http"
require "net/smtp"
require "timeout"

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
        end
    rescue Net::SMTPFatalError => e
        $stderr.puts "Couldn't send email from #{from} to #{to}. #{smtp_server}:#{smtp_port} said #{e.message}"
    end
end

def make_alert(c)
    res_proc = nil
    c["default_alert"].each do |a|
        case a
        when "email"
			res_proc = Proc.new { |args|
                unless args[:subject]
                    args[:subject] = "[Webwatchr] Site #{args[:name]} updated"
                end
                args.delete(:name)
                args[:smtp_server] = $CONF["alerts"]["email"]["smtp_server"]
                args[:smtp_port] = $CONF["alerts"]["email"]["smtp_port"]
                args[:to] = $CONF["alerts"]["email"]["dest_email"]
                send_mail(args)
            }
        when "rss"
            res_proc = Proc.new { |args|
                gen_rss(args)
            }
        else
            raise Exception("Unknown alert method : #{a}")
        end
    end
    return res_proc
end

def init()

    $MYDIR = File.dirname(__FILE__)

    unless $CONF["last_dir"]
        $CONF["last_dir"] = File.join($MYDIR, ".lasts")
    end
    FileUtils.mkdir_p($CONF["last_dir"])
    FileUtils.mkdir_p(File.join($MYDIR, "sites-enabled"))

    sites=Dir.glob(File.join($MYDIR, "sites-enabled", "*.rb"))

    if sites.empty?
        $stderr.puts "Didn't find any site to parse. You might want to "
        $stderr.puts "cd sites-enabled/; ln -s ../sites-available/something.rb . "
    end

    $CONF["alert_proc"] = make_alert($CONF)

    timeout = $CONF["site_timeout"] || 10*60
    sites.each do |site|
        begin
            if $VERBOSE
                puts "loading #{File.basename(site)}"
            end
            status = Timeout::timeout(timeout) {
                load site
            }
        rescue Net::ReadTimeout, Errno::ENETUNREACH => e
            # Do nothing, try later
            # TODO
            # Log Something when we have logs
        rescue Exception=>e
            $stderr.puts "Issue with #{site} : #{e}"
            $stderr.puts e.message
            $stderr.puts e.backtrace
        end
    end

end

def main()
    if not File.exist?("config.json")
        $stderr.puts "plz cp config.json.template config.json"
        $stderr.puts "and update it to your needs"
        exit
    else
        $CONF=JSON.parse(File.read("config.json"))
    end

    if File.exist?($CONF["pid_file"])
        puts "Already running"
        exit
    end
    begin
        File.open($CONF["pid_file"],'w+') {|f|
            f.puts($$)
            init()
        }
    ensure
        if File.exist?($CONF["pid_file"])
            FileUtils.rm $CONF["pid_file"]
        end
    end

end

main()
