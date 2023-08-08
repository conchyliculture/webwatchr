#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "json"

class Cainiao < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://global.cainiao.com/global/detail.json?mailNos=#{track_id}",
          every: every,
          test: test,
          comment: comment,
        )
    end

    def get_content()
        res = ["<ul>"]
        j = JSON.parse(@html_content)
        j['module'][0]['detailList'].each do |jj|
          res << "<li>#{jj['timeStr']}: #{jj['standerdDesc']}</li>"
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
