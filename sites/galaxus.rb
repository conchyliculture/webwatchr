#!/usr/bin/ruby
require_relative "../lib/site"

module Galaxus
  class Product < Site::SimpleString
    # Gets name & price for one product
    def get_content
      article = @parsed_content.css("article.pd-product")
      price = article.css("div.product-price").text
      product_text = article.css('h1.product-name span').map() { |x| x.text.strip }.join(' ')
      return "#{product_text} #{price.strip()} CHF"
    end
  end

  class DailyDeals < Site::Articles
    # Gets info from the daily deals
    def get_content
      @parsed_content.css("article.liveshoppingProduct").each do |a|
        img = a.css('img[src^="http"]')[0]['src']
        site_base = URI.parse(@url)
        site_base = site_base.to_s.sub(site_base.request_uri, "")
        url = "#{site_base}/#{a.css('a')[0]['href']}"
        title = a.css('div.productName').map() { |x| x.text.strip }.join(' ')
        price = a.css('div span strong').text
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

# Example:
#
#Galaxus::Product.new(
#    url:  "")
