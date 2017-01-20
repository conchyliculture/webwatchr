#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostNL < Site::SimpleString
    def get_content()
        res = []
        table = @parsed_content.css("tbody tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            $stderr.puts "Please verify the PostNL tracking ID"
            @logger.error "Please verify the PostNL tracking ID"
            return nil
        end
        headers = ["Date", "Status"]
        prev_place = ""
        table.each do |r|
            res << "#{r[0]} : #{r[1]}<br/>\n"
        end
        return res.join("")
    end
end

postnl_id="RSAAAAAAAAAAAAA"
PostNL.new(
    url:  "http://www.postnl.post/details/",
    post_data: {"barcodes" => postnl_id},
    every: 30*60,
    test: __FILE__ == $0
).update

