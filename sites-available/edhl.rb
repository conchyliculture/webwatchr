#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class EDHL < Site::SimpleString
    require "date"
    require "json"

    # Here we want to do check only part of the DOM.
    #   @http_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        res = []
        l = @parsed_content.css("ol.timeline li")
        if l.size == 0
            raise Site::ParseError.new("Please verify the eDHL tracking ID")
        end
        date = nil
        l.each do |l|
            case l.attr("class")
            when "timeline-date"
                date = l.text
            when /timeline-event/
                time = l.css("div.timeline-time").text.strip()
                loc = l.css("div.timeline-location").text.strip()
                descr = l.css("div.timeline-description").text.strip()
                res << "#{date} #{time}: #{descr}"
            end
        end

        return res.join("<br/>\n")
    end

end

trackingnb="000000"
EDHL.new(
    url: "http://webtrack.dhlglobalmail.com/?mobile=&trackingnumber=#{trackingnb}",
    every: 60*60,
   test: __FILE__ == $0
).update

