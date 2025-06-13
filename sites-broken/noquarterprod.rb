require_relative "../webwatchr/site"

class NQP < Site::Articles
  require "net/http"
  require "nokogiri"

  def initialize(artist_id:, every: 60 * 60, comment: nil)
    super(
      url: "http://www.noquarterprod.com/product-category/#{artist_id}/",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    @alread_fetched_urls = []
    return get_products(@parsed_content)
  end

  def get_products(noko)
    real_products = noko.css("li.purchasable")
    if real_products.empty?
      noko.css("li.product a").each do |p|
        url = p.attr("href")
        next if @alread_fetched_urls.include?(url)

        @alread_fetched_urls << url
        root = Nokogiri::HTML(Net::HTTP.get(URI(url)))
        get_products(root)
      end
    else
      real_products.each do |p|
        url = p.css("a").attr("href").text
        img_url = p.css("a img").attr("src").text
        title = p.css("a h3").text
        price = p.css("span.amount").text
        add_article({
                      "id" => url,
                      "url" => url,
                      "img_src" => img_url,
                      "title" => "#{title} - #{price}"
                    })
      end
    end
  end
end

# Example:
#
# NQP.new(
#     artist_id: "carpenter-brut-en",
#     )
