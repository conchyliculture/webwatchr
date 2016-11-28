$: << File.dirname(__FILE__)

require "classe.rb"
require "json"

class AmazonCyber < Classe

    # Here we want to do something different: calculate a Hash of only part of the HTML
    # There classic way to do it is to overload get_content() and make it return only part of the DOM, as string
    #   @http_content contains the whole html page
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        res=[]
        # Selects the content of the first table tag with the CSS class result-summary
        js = @parsed_content.css("script").select{|x| x.content=~/window.gb.widgetsToRegister/}[0].content
        magic = '"dealDetails" : {'
        js = js[js.index(magic)+magic.size()..-1]
        json="{"
        cpt=1
        js.each_char do |b|
            case b
            when "{"
                cpt+=1
            when "}"
                cpt-=1
            end
            json << b
            break if cpt==0
        end
        json = JSON.parse(json)
        json.each do | deal|
            deal.each do |d|
                next if d.class == String
                url = d["egressUrl"] || @url
                pic = d["primaryImage"] || d["teaserImage"]
                price = d["maxCurrentPrice"] || "Later offer"
                name = d["title"]
                res << {"href" => url,
                        "img_src" => pic,
                        "name" => "#{name} - #{price}" ,
                } 
            end
        end

        return res
    end

end

AmazonCyber.new(
    url:  "https://www.amazon.fr/gp/goldbox/",
    every: 30*60,
    test: __FILE__ == $0
)

