$: << File.dirname(__FILE__)
require "pp"

require "classe.rb"

class Galaxus < Classe

    def get_content
        res = []
        @parsed_content.css("article").each do |a|
            unless a.css("div.lazy-image img").empty?
                img = "https:"+a.css("div.lazy-image img").attr("src").value()
                if img =~ /data:image\/gif;base64/
                    img = "https:"+a.css("div.lazy-image img").attr("data-src").value()
                end
                site_base = URI.parse(@url) 
                site_base = site_base.to_s.sub(site_base.request_uri,"")
                url = site_base + "/" + a.css("a.overlay")[0].attr('href')
                title = a.css("h5.product-name").text.split("\n").join("")
                price = "?" 
                if a.css("div.product-price")
                    price = a.css("div.product-price").text.split(".–")[0].strip
                end
                res << {"href" => url,
                        "img_src" => img,
                        "name" => "#{title} - #{price}" ,
                } 
                pp res
            end
        end
        return res
    end
end


Galaxus.new(url:  "https://www.galaxus.ch/en/LiveShopping",
              every: 12*60, 
              test: __FILE__ == $0
           ).update
Galaxus.new(url:  "https://www.digitec.ch/en/LiveShopping",
              every: 12*60, 
              test: __FILE__ == $0
           ).update