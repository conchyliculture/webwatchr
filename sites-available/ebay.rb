#!/usr/bin/ruby

require_relative "../lib/site.rb"

class Ebay < Site::Articles 

    def initialize(search_request:, every:, comment:nil, test:false)
        super(
            url:  "https://www.ebay.com/sch/i.html?LH_PrefLoc=2&_nkw=#{search_request}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        @parsed_content.css('li.s-item').each do |article|
            a = article.css('div.s-item__image a')
            url = nil
            if a.size > 0
              uri = a[0]['href']
              url = URI.parse(uri)
              url = "https://"+url.host+url.path
            end

            next unless url

            image = article.css('img.s-item__image-img')[0]['src']
            title = article.css('h3.s-item__title')[0].text
            price = article.css('span.s-item__price')[0].text

            add_article({
            "id" => url,
            "url" => url,
            "title" => title + " " + price,
            "img_src" => image
            })
        end
    end
end

# Example:
#
# # Add some terms to search
# search_terms = []
# search_terms.each do |term|
#     Ebay.new(
#         search_request: term,
#         every: 30*60,
#         test: __FILE__ == $0
#     ).update
# end
