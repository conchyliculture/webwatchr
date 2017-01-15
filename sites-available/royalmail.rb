#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class RoyalMail < Site::SimpleString
    require "date"

    # Here we want to do check only part of the DOM.
    #   @http_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        # Selects the content of the first table tag with the CSS class result-summary
        res = ""
        table = @parsed_content.css("table.sticky-enabled")
        if table.size == 0
            $stderr.puts "Please verify the RoyalMail tracking ID #{@url}"
            @logger.err "Please verify the RoyalMail tracking ID #{@url}"
            return nil
        end
        headers = table[0].css("th").map{|x| x.text.strip}
        table.css("tr")[1..-1].each do |tr|
            row = tr.css("td").map{|x| x.text.strip().gsub(/[\r\n\t]/,"").gsub(/  +/," ")}
            begin
                time = DateTime.strptime("#{row[0]} #{row[1]}","%d/%m/%y %H:%M")
                res << "#{time} : #{row[2]}<br/>\n"
            rescue Exception
                res << row.join(" ")
            end
        end
        return res
    end

end

trackingnb = "RN000000000GB"
RoyalMail.new(
    url: "https://www.royalmail.com/track-your-item?trackNumber=#{trackingnb}",
    every: 60*60,
    test: __FILE__ == $0
).update

