require_relative "../lib/site"

class Songkick < Site::Articles
  def full_url(url)
    @url = url
    unless @url.end_with?("/calendar")
      logger.warn("Songkick should end with /calendar to get all concerts")
    end
    return self
  end

  def get_content()
    events = @parsed_content.css('ol.event-listings')[0]
    events.css('li').each do |event|
      j = JSON.parse(event.css('script')[0].text)[0]
      date = j["startDate"]
      url = j["url"]
      artist = j["name"]
      loc = j["location"]
      location = "#{loc['name']} #{loc['address']['addressLocality']}, #{loc['address']['addressCountry']}"
      add_article({
                    "id" => url,
                    "url" => url,
                    "title" => "#{date}: #{artist} at #{location}"
                  })
    end
  end
end
