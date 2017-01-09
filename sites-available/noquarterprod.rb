#!/usr/bin/ruby
# encoding: utf-8

require_relative "../sites-available/classe.rb"

class NQP < Classe
    require "net/http"
    require "nokogiri"

    def get_content()
        @alread_fetched_urls = []
        return get_products(@parsed_content)
    end

    def get_products(noko)
        res = []
        real_products = noko.css("li.purchasable")
        if real_products.empty?
            noko.css("li.product a").each do |p|
                url = p.attr('href')
                next if @alread_fetched_urls.include?(url)
                @alread_fetched_urls << url
                root = Nokogiri::HTML(Net::HTTP.get(URI(url)))
                res = res.concat(get_products(root))
            end
            return res
        else
            real_products.each do |p|
                url = p.css('a').attr('href').text
                img_url = p.css('a img').attr('src').text
                title = p.css('a h3').text
                price = p.css('span.amount').text
                res << {"href"=> url,
                        "img_src" => img_url,
                        "name" => "#{title} - #{price}",
                }
            end
            return res.uniq
        end
    end
end


NQP.new(url:  "http://www.noquarterprod.com/product-category/carpenter-brut-en/",
              every: 12*60*60,
              test: __FILE__ == $0
       ).update()
