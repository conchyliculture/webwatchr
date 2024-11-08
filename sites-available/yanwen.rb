#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "json"

class YanWen < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://track.yw56.com.cn/en/querydel?nums=#{track_id}",
          every: every,
          test: test,
          comment: comment,
        )
    end

    def get_content()
        res = []
        return @parsed_content.css('div.container div div.cx_top_nr div.colFlex')[4].text
#        @parsed_content.css('div.czhaodl ul li').each  do |jj|
#          time = jj.css("div.cz_r p")[0].text
#          desc = jj.css("div.cz_r h6")[0].text
#          res << "<li>" + time + ": " + desc + "</li>"
#        end
#        res.sort!.uniq!
#        if res.size() > 0
#          res = ["<ul>"] << res << ["</ul>"]
#          return res.join("\n")
#        end
#        return nil
    end
end

# Example:
#
# YanWen.new(
#     track_id: "UJ000000000YP",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
