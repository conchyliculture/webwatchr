#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Colisprive < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://www.colisprive.com/moncolis/pages/detailColis.aspx?numColis=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
        res = []
        table = @parsed_content.css("table.tableHistoriqueColis tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            raise Site::ParseError.new("Please verify the ColisPrivé tracking ID")
        end
        table.each do |r|
            next if "#{r[0]}#{r[1]}" == ""
            res << "#{r[0]} : #{r[1]}"
            if r[2].to_s != ""
                res << " (#{r[2]})"
            end
            res << "<br/>\n"
        end
        return res.join("")
    end
end

Colisprive.new(
    track_id: "55600000000000000",
    every: 60*60,
    test: __FILE__ == $0
).update

