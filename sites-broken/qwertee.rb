require_relative "../webwatchr/site"

class Qwertee < Site::Articles
  def initialize(every: 60 * 60, comment: nil)
    super(
      url: "https://www.qwertee.com/rss/",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    Nokogiri.parse(@html_content).xpath("rss/channel/item").each do |entry|
      shirt_name = entry.xpath("title").first.content
      shirt_url = entry.xpath("guid").first.content
      entry_description = Nokogiri::HTML(entry.xpath("description").first.content)
      entry_description.remove_namespaces!
      shirt_photo_url = entry_description.xpath("//img").first["src"]

      add_article({
                    "title" => shirt_name,
                    "id" => shirt_url,
                    "url" => shirt_url,
                    "img_src" => shirt_photo_url
                  })
    end
  end
end

# Example:
#
# Qwertee.new()
