#!/usr/bin/ruby

$:<< File.dirname(__FILE__)
$:<< File.join(File.dirname(__FILE__),"libs")
require "fileutils"
require "json"

def is_running?()
    return File.exists?($CONF["pid_file"])
end

def init()
    FileUtils.mkdir_p($CONF["last_dir"])
    if is_running?()
        puts "Already running"
        exit
    end
    FileUtils.touch $CONF["pid_file"]
    sites=[]
    if $CONF["sites_enabled"] == "ALL"
        sites=Dir.glob("sites/*.rb").map{|s| File.basename(s)} - ["classe.rb"]
    else
        sites=$CONF["sites_enabled"]
    end

    sites.each do |site|
        next if $CONF["sites_disabled"].include?(site)
        begin
            if $VERBOSE
                puts "loading sites/#{site}"
            end
            load "sites/#{site}"
        rescue Exception=>e
            $stderr.puts "Issue with #{site}"
            $stderr.puts e.message
            $stderr.puts e.backtrace
        end
    end

end

def main()
    if not File.exists?("config.json")
        $stderr.puts "plz cp config.json.template config.json"
        $stderr.puts "and update it to your needs"
        exit   
    else
    $CONF=JSON.parse(File.read("config.json"))
    end
    
    begin
        init()
    ensure
        FileUtils.rm $CONF["pid_file"]
    end

end

main()
