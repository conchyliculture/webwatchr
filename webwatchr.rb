#!/usr/bin/ruby

$:<< File.dirname(__FILE__)

require "fileutils"
require "json"
require "timeout"

def init()
    FileUtils.mkdir_p($CONF["last_dir"])
    sites=[]
    if $CONF["sites_enabled"] == "ALL"
        sites=Dir.glob("sites/*.rb").map{|s| File.basename(s)} - ["classe.rb"]
    else
        sites=$CONF["sites_enabled"]
    end

    timeout = $CONF["site_timeout"] || 10*60
    sites.each do |site|
        next if $CONF["sites_disabled"].include?(site)
        begin
            if $VERBOSE
                puts "loading sites/#{site}"
            end
            status = Timeout::timeout(timeout) {
                load "sites/#{site}"
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
