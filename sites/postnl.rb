#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostNL < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "http://www.postnl.post/details/",
            post_data: {"barcodes" => track_id},
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = []
        table = @parsed_content.css("tbody tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            raise Site::ParseError.new "Please verify the PostNL tracking ID"
        end
        table.each do |r|
            res << "#{r[0]} : #{r[1]}<br/>\n"
        end
        return res.join("")
    end
end

# Example:
#
# PostNL.new(
#     track_id: "RSAAAAAAAAAAAAA",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
