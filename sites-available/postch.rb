#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostCH < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = []
        table = @parsed_content.css("table.events_view tr").map{|row| row.css("td").map{|r| r.text.strip}}.delete_if{|x| x.empty?}
        if table.size==0
            raise Site::ParseError.new "Please verify the PostCH tracking ID"
        end
        table.each do |r|
            res << "#{r[0]} - #{r[1]} : #{r[3]}: #{r[2].split("\n")[-1].strip()}<br/>\n"
        end
        return res.join("")
    end
end

# Example:
#
# PostCH.new(
#     track_id: "99.60.00000.00000000",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
