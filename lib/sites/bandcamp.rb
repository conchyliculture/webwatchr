require_relative "../webwatchr/site"

class BandcampMerch < Site::Articles
  require "net/http"
  require "nokogiri"

  def band(value)
    @band = value
    @url = "https://#{@band}.bandcamp.com/merch"
    self
  end

  def extract_articles()
    if @website_html =~ /You are being redirected, please follow <a href="([^"]+)"/
      new_url = ::Regexp.last_match(1)
      @website_html = Net::HTTP.get(URI.parse(new_url))
      @parsed_html = Nokogiri::HTML.parse(@website_html)
      item = @parsed_html.css('div#merch-item')
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
      @parsed_html.css('ol.merch-grid li').each do |xx|
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
  end
end
