#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Colissimo < Site::SimpleString
    def get_content()
        res = []
        table = @parsed_content.css("tbody tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            $stderr.puts "Please verify the Colissimo tracking ID"
            @logger.error "Please verify the Colissimo tracking ID"
            return nil
        end
        headers = ["Date", "Status"]
        prev_place = ""
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

colissimo_id="CW0000000000FR"
Colissimo.new(
    url:  "http://www.colissimo.fr/portail_colissimo/suivreResultatStubs.do",
    post_data: {"parcelnumber" => colissimo_id},
    every: 2*60*60,
    test: __FILE__ == $0
).update

