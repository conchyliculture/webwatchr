#!/usr/bin/ruby

require_relative "../lib/site"
require "openssl"

class Ricardo < Site::Articles
  def initialize(search_term:, every:, ignore: nil, comment: nil)
    super(
      url: "https://www.ricardo.ch/fr/s/#{URI.encode_www_form_component(search_term)}",
      every: every,
      comment: comment,
    )
    @ignore = ignore
  end

  def get_content()
    @parsed_content.css('div.MuiGrid-container a.MuiGrid-item').each do |article|
      url = "https://www.ricardo.ch" + article['href']
      images = article.css('img')
      image = if images.size > 0
                images[0]['src']
              else
                "nope"
              end
      title = article.css('p').text

      if @ignore and title =~ /#{@ignore}/i
        next
      end

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
#     ).update
# end
