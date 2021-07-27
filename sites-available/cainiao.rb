#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "json"

class Cainiao < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://global.cainiao.com/detail.htm?mailNoList=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
        res = ["<ul>"]
        j = JSON.parse(@parsed_content.css('textarea#waybill_list_val_box').text)
        j['data'][0]['section2']['detailList'].each do |jj|
          res << "<li>#{jj['time']}: #{jj['desc']}</li>"
        end
        res << ["</ul>"]
        return res.join("\n")
    end
end

# Example:
#
# Cainiao.new(
#     track_id: "RB000000000SG",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
