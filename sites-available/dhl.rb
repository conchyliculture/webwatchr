#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class DHL < Site::SimpleString
    def get_content()
        div = @parsed_content.css('div.well-status')
        if div.empty?
            raise Site::ParseError.new "Please verify the DHL tracking ID"
        end
        return div.text.gsub("\t", "")
    end
end

trackingnb = "000000000000"
DHL.new(
    url:  "https://nolp.dhl.de/nextt-online-public/en/search?piececode=#{trackingnb}",
    every: 60*60,
   test: __FILE__ == $0
).update

