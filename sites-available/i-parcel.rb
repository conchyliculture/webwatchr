#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class IParcel < Site::SimpleString
    def get_content()
        res = []
        table = @parsed_content.css("div.result").each{|row|
            date = row.css("div.date").text.split("\n").map{|s| s.strip()}.join(" ")
            what = row.css("div.event").text.split("\n").map{|s| s.strip()}.join(" ")
            res << "#{date} #{what}<br/>\n"
        }

        return res.join("")
    end
end

iparcel = "AEIEDE00000000000"
IParcel.new(
    url:  "https://tracking.i-parcel.com/Home/Index?trackingnumber=#{iparcel}",
    every: 60*60,
    test: __FILE__ == $0
).update

