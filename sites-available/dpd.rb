#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

require "json"
require "pp"

class DPD < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://tracking.dpd.de/rest/plc/en_US/#{track_id}",
          every: every,
          test: test,
          comment: comment,
        )
    end

    def get_content()
        res = ["<ul>"]
        j = JSON.parse(@html_content)
        if j
          j["parcellifecycleResponse"]["parcelLifeCycleData"]["statusInfo"].select{|i| i["statusHasBeenReached"]}.each{|x|
            date = x["date"]
            place = x["location"]
            descr = x["description"]["content"].join(' ')
            res << "<li>#{date} #{place} #{descr}</li>"
          }
        else
            raise Site::ParseError.new "Please verify the DPD tracking ID"
        end
        res << ["</ul>"]
        return res.join("\n")
    end
end

# Example:
#
# DPD.new(
#     track_id: "000000000000",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
