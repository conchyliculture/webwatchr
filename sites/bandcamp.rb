#!/usr/bin/ruby
require_relative "../lib/site"

class Bandcamp < Site::Articles
  require "net/http"
  require "nokogiri"

  def initialize(band, every: 60 * 60, merch: true)
    @merch = merch
    super(url: "https://#{band}.bandcamp.com/#{'merch' if @merch}", every: every)
  end

  def get_content()
    if @merch
      if @html_content =~ /You are being redirected, please follow <a href="([^"]+)"/
        new_url = ::Regexp.last_match(1)
        @html_content = Net::HTTP.get(URI.parse(new_url))
        @parsed_content = Nokogiri::HTML.parse(@html_content)
        item = @parsed_content.css('div#merch-item')
        if item.css(".notable").text == "Sold Out"
          logger.debug "That item is sold out =("
          return
        end
        url = new_url
        title = item.css("h2.title").text
        img_url = item.css("img.main-art").attr("src").text
        add_article({
                      "id" => url,
                      "url" => url,
                      "img_src" => img_url,
                      "title" => title
                    })
      else
        @parsed_content.css('ol.merch-grid li').each do |xx|
          unless xx.css('p.sold-out').empty?
            logger.debug "That item is sold out =("
            next
          end
          x = xx.css('a')
          url = "http://#{URI.parse(@url).host + x.attr('href').text}"
          img = x.css('img')
          img_url = img.attr('src').text
          if img_url =~ /\/img\/43.gif/
            img_url = img.attr('data-original')
          end
          title = x.css('p.title').text.strip().gsub(/ *\n */, '')
          price = x.css('span.price').text
          add_article({
                        "id" => url,
                        "url" => url,
                        "img_src" => img_url,
                        "title" => "#{title} #{price}"
                      })
        end
      end
    else
      warn "I only support /merch bandcamp links"
    end
  end
end

# Example:
#
# Bandcamp.new(
#     band,
#     merch: true
# )
