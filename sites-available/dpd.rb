#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

require "json"
require "pp"

class DPD < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://tracking.dpd.de/cgi-bin/simpleTracking.cgi?parcelNr=#{track_id}&locale=en_D2&type=1&jsoncallback=_jqjsp",
            every: every,
            test: test,
            comment: comment,
        )
    end

    def parse_content(html)
        if html=~/_jqjsp\((.+)\)/m
            return JSON.parse($1)
        end
        return nil
    end

    def get_content()
        res = []
        j = @parsed_content
        if j
            j["TrackingStatusJSON"]["statusInfos"].each{|x|
                date = x["date"]+" "+x["time"]
                place = x["city"]
                descr = x["contents"].map {|c| c["label"]}.join
                res << "#{date} #{place} #{descr}"
            }
        else
            raise Site::ParseError.new "Please verify the DPD tracking ID"
        end
        return res.join("<br/>\n")
    end
end

# Example:
#
# DPD.new(
#     track_id: "000000000000",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
