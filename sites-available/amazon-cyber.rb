#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class AmazonCyber < Site::Articles
    require "json"

    def get_content()
        @logger.warn "This site is probably not working"
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
                add_article({
                    "id"=>"url",
                    "url" => url,
                    "img_src" => pic,
                    "title" => "#{name} - #{price}" ,
                })
            end
        end
    end

end

AmazonCyber.new(
    url:  "https://www.amazon.fr/gp/goldbox/",
    every: 30*60,
    test: __FILE__ == $0
).update()

