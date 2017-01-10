#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class DHL < Site::SimpleString

    # Here we want to do check only part of the DOM.
    #   @http_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        # Selects the content of the first table tag with the CSS class result-summary
        return @parsed_content.css("table.result-summary")[0].to_s
    end

end

# trackingnb=1234567890
#DHL.new(
#    url:  "http://www.dhl.com/en/express/tracking.html?AWB=#{trackingnb}&brand=DHL",
#    every: 10*60,
#    test: __FILE__ == $0
#).update

