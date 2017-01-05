#!/usr/bin/ruby

$:<< File.dirname(__FILE__)

require "fileutils"
require "json"
require "timeout"

def send_mail(dest_email: nil, content: nil, from: $from, subject:nil , smtp: , smtp_port:,)

    msgstr = <<END_OF_MESSAGE
From: #{from}
To: #{dest_email}
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
Subject: #{subject}

#{content}
END_OF_MESSAGE

    Net::SMTP.start(smtp_server, smtp_port) do |smtp|
        smtp.send_message(msgstr, from, dest_email)
    end
end

def make_alert(c)
    res_proc = nil
    c["default_alert"].each do |a| 
        case a
        when "email"
            res_proc = Proc.new { |new_args|

                subject = new_args[:subject]
                unless subject
                    subject= "[Webwatchr] Site #{new_args[:name]} updated"
                end
                args[:content] = new_args[:content]
                args[:subject] = subject
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
end

def init()

    $MYDIR=File.dirname(__FILE__)

    FileUtils.mkdir_p(File.join($MYDIR, $CONF["last_dir"]))
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
        rescue Exception=>e
            $stderr.puts "Issue with #{site}"
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
