#!/usr/bin/ruby
# encoding: utf-8

require_relative "../sites-available/classe.rb"

class PostNL < Classe
    def get_content()
        res = []
        table = @parsed_content.css("tbody tr").map{|row| row.css("td").map{|r| r.text.strip}}
        if table.size==0
            $stderr.puts "Please verify the PostNL tracking ID"
            return nil
        end
        headers = ["Date", "Status"]
        places=[]
        prev_place = ""
        table.each do |r|
            res << "#{r[0]} : #{r[1]}<br/>\n"
        end
        return res.join("")
    end
end

$ID="RSAAAAAAAAAAAAA"
PostNL.new(url:  "http://www.postnl.post/details/",
           post_data: {"barcodes" => $ID},
              every: 30*60,
              test: __FILE__ == $0
          ).update

