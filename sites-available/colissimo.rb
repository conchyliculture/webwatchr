#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Colissimo < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "http://www.colissimo.fr/portail_colissimo/suivreResultatStubs.do",
            post_data: {"parcelnumber" => track_id},
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
        res = []
        table = @parsed_content.css("tbody tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            Site::ParseError("Please verify the Colissimo tracking ID")
        end
        table.each do |r|
            res << "#{r[0]} : #{r[1]}"
            if r[2].to_s != ""
                res << " (#{r[2]})"
            end
            res << "<br/>\n"
        end
        return res.join("")
    end
end

Colissimo.new(
    track_id: "CW0000000000FR",
    every: 2*60*60,
    test: __FILE__ == $0
).update

