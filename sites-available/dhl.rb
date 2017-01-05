$: << File.dirname(__FILE__)

require "classe.rb"

class DHL < Classe 

    # Here we want to do something different: calculate a Hash of only part of the HTML
    # There classic way to do it is to overload get_content() and make it return only part of the DOM, as string
    #   @http_content contains the whole html page
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        # Selects the content of the first table tag with the CSS class result-summary
        return @parsed_content.css("table.result-summary")[0].to_s
    end

end

# trackingnb=1234567890
# d=DHL.new(url:  "http://www.dhl.com/en/express/tracking.html?AWB=#{trackingnb}&brand=DHL",
#              every: 10*60, 
#              test: __FILE__ == $0
#             ).update

