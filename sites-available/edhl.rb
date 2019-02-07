#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class EDHL < Site::SimpleString
    require "date"
    require "json"

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "http://webtrack.dhlglobalmail.com/?mobile=&trackingnumber=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = []
        l = @parsed_content.css("ol.timeline li")
        if l.size == 0
            raise Site::ParseError.new("Please verify the eDHL tracking ID")
        end
        date = nil
        l.each do |ll|
            case ll.attr("class")
            when "timeline-date"
                date = ll.text
            when /timeline-event/
                time = ll.css("div.timeline-time").text.strip()
                descr = ll.css("div.timeline-description").text.strip()
                res << "#{date} #{time}: #{descr}"
            end
        end

        return res.join("<br/>\n")
    end

end

EDHL.new(
    track_id: "000000",
    every: 60*60,
    test: __FILE__ == $0
).update

