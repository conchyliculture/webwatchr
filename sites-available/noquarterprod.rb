#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class NQP < Site::Articles
    require "net/http"
    require "nokogiri"

    def get_content()
        @alread_fetched_urls = []
        return get_products(@parsed_content)
    end

    def get_products(noko)
        real_products = noko.css("li.purchasable")
        if real_products.empty?
            noko.css("li.product a").each do |p|
                url = p.attr("href")
                next if @alread_fetched_urls.include?(url)
                @alread_fetched_urls << url
                root = Nokogiri::HTML(Net::HTTP.get(URI(url)))
                get_products(root)
            end
        else
            real_products.each do |p|
                url = p.css("a").attr("href").text
                img_url = p.css("a img").attr("src").text
                title = p.css("a h3").text
                price = p.css("span.amount").text
                add_article({
                    "id"=>url,
                    "url"=>url,
                    "img_src"=>img_url,
                    "title"=>"#{title} - #{price}",
                })
            end
        end
    end
end

NQP.new(
    url:  "http://www.noquarterprod.com/product-category/carpenter-brut-en/",
    every: 12*60*60,
    test: __FILE__ == $0
).update
