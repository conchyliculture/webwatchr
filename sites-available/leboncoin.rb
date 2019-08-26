#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Leboncoin < Site::Articles 
    def get_content()
        @parsed_content.css('section.tabsContent li').each do |art|
            link = "https:"+art.css('a').attr('href').text
            img = art.css("span.lazyload")[0].attr('data-imgsrc')
            price = art.css("h3.item_price").text.strip
            title = art.css("h2.item_title").text.strip
            add_article({
                "id" => link,
                "url" => link,
                "title" => "#{title} #{price}",
                "img_src" => img
            })
        end
    end
end

# Example:
#
# region = "ile_de_france"
# dept = "paris"
# cat = "telephonie"
# search = "mon tel de reve"
# Leboncoin.new(
#     url:  "https://www.leboncoin.fr/#{cat}/offres/#{region}/#{dept}/?q=#{search}",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
