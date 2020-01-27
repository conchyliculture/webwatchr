#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "openssl"

class Ricardo < Site::Articles 
    def initialize(search_term:, every:, comment:nil, test:false)
        super(
            url:  URI.encode("https://www.ricardo.ch/fr/s/#{search_term}"),
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
      @parsed_content.css('div.MuiGrid-container a.MuiGrid-item').each do |article|
            url = "https://www.ricardo.ch"+article['href']
            images = article.css('img')
            if images.size >0 
              image = images[0]['src']
            else
              image = "nope"
            end
            title = article.css('p').text

            add_article({
            "id" => url,
            "url" => url,
            "title" => title,
            "img_src" => image
            })
        end
    end
end

# Example:
#
# # Add some terms to search
# [].each do |term|
#     Ricardo.new(
#         search_term: term,
#         every: 30*60,
#         test: __FILE__ == $0
#     ).update
# end
