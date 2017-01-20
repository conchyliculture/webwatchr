#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class USPS < Site::SimpleString
    require "date"

    def get_content()
        res = ""
        table = @parsed_content.css("table.zebra-table tr")
        if table.size == 0
            $stderr.puts "Please verify the USPS tracking ID #{@url}"
            @logger.error "Please verify the USPS tracking ID #{@url}"
            return nil
        end
        headers = table[0].css("th").map{|x| x.text.strip}
        table.css("tr")[1..-1].each do |tr|
            row = tr.css("td").map{|x| x.text.strip().gsub(/[\r\n\t]/,"").gsub(/  +/," ")}
            next if row.size < 3
            if row[1] != ""
                begin
                    time = DateTime.strptime("#{row[0]}","%B %d, %Y,%H:%M %p")
                rescue Exception
                end
                res << "#{time} : #{row[1]} #{row[2]}<br/>\n"
            else
                res << "#{row[0]}<br/>\n"
            end
        end
        return res
    end

end

trackingnb = "LZ000000000US"
USPS.new(
    url: "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{trackingnb}",
    every: 60*60,
    test: __FILE__ == $0
).update

