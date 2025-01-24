require "cgi"
require "json"

require_relative "../lib/site"

# Here list the categories you're not interested in

class Dealabs < Site::Articles
  BADCATEGORY = Regexp.union(
    [
      /^mode$/,
      /^(e\. leclerc|carrefour|auchan|boulanger|fnac)$/,
      /^Épicerie$/,
      /itunes/,
      /google play/
    ]
  )
  def initialize(every: 60 * 60, comment: nil)
    super(
      url: "https://www.dealabs.com/",
      every: every,
      comment: comment,
    )
  end

  def match_category(categories)
    categories.each do |category|
      return true if category =~ BADCATEGORY
    end
    return false
  end

  def get_content()
    Nokogiri.parse(@html_content).css("article").each do |article|
      next if article.attr('class') =~ /expired/

      img_html = article.css('a.imgFrame')
      header_div = article.css('div.threadGrid-title')
      link = ""
      unless img_html.empty?
        link = img_html.attr('href').text
      end
      next if header_div.empty?

      title = header_div.css('a.thread-link').text.strip
      categories = article.css('span.cept-merchant-name').map { |x| x.text.downcase }
      img_ = article.css('img.imgFrame-img')
      img = img_.attr('src').text
      if img =~ /^data:image\/gif;base64/
        img = JSON.parse(CGI.unescapeHTML(img_.attr('data-lazy-img')))["src"]
      end
      if match_category(categories)
        logger.debug "Ignoring #{title} because #{categories} have bad category"
        next
      end
      add_article({
                    "id" => link,
                    "url" => link,
                    "title" => "#{title}  / (#{categories.join('|')})",
                    "img_src" => img
                  })
    end
  end
end
