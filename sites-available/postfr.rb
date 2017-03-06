#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostFR < Site::SimpleString
    def get_content()
        res = []
        table = @parsed_content.css("table.table tr").map{|row| row.css("td").map{|r| r.text.strip}}.delete_if{|x| x.empty?}
        if table.size==0
            raise Site::ParseError.new "Please verify the PostFR tracking ID"
        end
        table.each do |r|
            res << "#{r[0]} #{r[1]}"
        end
        return res.join("<br/>")
    end
end

$postfr_id = "6Y000000000"
PostFR.new(
    url: "http://www.laposte.fr/particulier/outils/suivre-vos-envois",
    post_data: {
    "suivi[number]"=> $postfr_id,
    },
    every: 30*60,
    test: __FILE__ == $0
).update


