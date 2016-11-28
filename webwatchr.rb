#!/usr/bin/ruby

$:<< File.dirname(__FILE__)

require "fileutils"
require "json"
require "timeout"

def init()

    $MYDIR=File.dirname(__FILE__)

    FileUtils.mkdir_p(File.join($MYDIR, $CONF["last_dir"]))
    FileUtils.mkdir_p(File.join($MYDIR, "sites-enabled"))

    sites=Dir.glob(File.join($MYDIR, "sites-enabled", "*.rb"))

    if sites.empty?
        $stderr.puts "Didn't find any site to parse. You might want to "
        $stderr.puts "cd sites-enabled/; ln -s ../sites-available/something.rb . "
    end

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
