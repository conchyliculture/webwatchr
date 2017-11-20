#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

module Galaxus

    class Product < Site::SimpleString
        # Gets name & price for one product
        def get_content
            article = @parsed_content.css("article.pd-product")
            price = article.css("div.product-price").text
            product_text = article.css('h1.product-name span').map() {|x| x.text.strip}.join(' ')
            return product_text+" "+price.strip()+" CHF"
        end
    end

    class DailyDeals < Site::Articles
        # Gets info from the daily deals
        def get_content
            @parsed_content.css("article").each do |a|
                unless a.css("div.lazy-image img").empty?
                    img = "https:"+a.css("div.lazy-image img").attr("src").value()
                    if img =~ /data:image\/gif;base64/
                        img = "https:"+a.css("div.lazy-image img").attr("data-src").value()
                    end
                    site_base = URI.parse(@url)
                    site_base = site_base.to_s.sub(site_base.request_uri, "")
                    url = site_base + "/" + a.css("a.product-overlay")[0].attr("href")
                    title = a.css("h5.product-name").text.split("\n").join("").gsub("\r","")
                    price = "?"
                    if a.css("div.product-price")
                        price = a.css("div.product-price").text.split(".–")[0].strip
                    end
                    add_article({
                        "id" => url,
                        "url" => url,
                        "img_src" => img,
                        "title" => "#{title} - #{price}"
                    })
                end
            end
        end
    end
end

#Galaxus::Product.new(
#    url:  "",
#    every: 2*60*60,
#    test: __FILE__ == $0
#).update

Galaxus::DailyDeals.new(
    url:  "https://www.galaxus.ch/en/LiveShopping",
    every: 12*60*60,
    test: __FILE__ == $0
).update

Galaxus::DailyDeals.new(
    url:  "https://www.digitec.ch/en/LiveShopping",
    every: 12*60*60,
    test: __FILE__ == $0
).update
