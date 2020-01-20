#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

require "json"

class DHL < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "https://www.dhl.com/shipmentTracking?AWB=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = ""
#        begin
            j = JSON.parse(@html_content)
            status = j.dig("results",0, "delivery", "status")
            res << status + "\n"
            j.dig("results", 0, "checkpoints"). each do |update|
              res << "#{update['date']} #{update['time']}: #{update['description']}\n"
            end
#        rescue
#            raise Site::ParseError.new "Please verify the DHL tracking ID"
#        end

        return res

    end
end

# example:
# DHL.new(
#     track_id: "0000000000",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
