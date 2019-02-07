#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostDE < Site::SimpleString
    def initialize(track_id:, post_day:, post_month:, post_year:, every:, comment:nil, test:false)
        super(
            url: "https://www.deutschepost.de/sendung/simpleQueryResult.html",
            post_data: {
                "form.sendungsnummer" => track_id,
                "form.einlieferungsdatum_monat" => post_month,
                "form.einlieferungsdatum_tag" => post_day,
                "form.einlieferungsdatum_jahr" => post_year,
            },
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = []
        table = @parsed_content.css("div.dp-table table tr").map{|row| row.css("td").map{|r| r.text.strip}}.delete_if{|x| x.empty?}
        if table.size==0
            raise Site::ParseError.new "Please verify the PostDE tracking ID"
            return nil
        end
        table.each do |r|
            res << "#{r[1]}"
        end
        return res.join("")
    end
end

PostDE.new(
    track_id: "Rblol",
    post_day: 16,
    post_month: 2 ,
    post_year: 2017,
    every: 30*60,
    test: __FILE__ == $0
).update
