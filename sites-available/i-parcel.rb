#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class IParcel < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://tracking.i-parcel.com/Home/Index?trackingnumber=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = []
        @parsed_content.css("div.result").each{|row|
            date = row.css("div.date").text.split("\n").map{|s| s.strip()}.join(" ")
            what = row.css("div.event").text.split("\n").map{|s| s.strip()}.join(" ")
            res << "#{date} #{what}<br/>\n"
        }

        return res.join("")
    end
end

# Example:
#
# IParcel.new(
#     track_id: "AEIEDE00000000000",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
