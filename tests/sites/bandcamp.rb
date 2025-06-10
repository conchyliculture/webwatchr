require "test/unit"
require_relative "../helpers"
require_relative "../../lib/sites/bandcamp"

class BandcampTests < ArticleSiteTest
  class BandcampMerchTest < BandcampMerch
    def pull_things
      @website_html = File.read(File.join(__dir__, "data/bandcamp"))
      @parsed_html = Nokogiri::HTML.parse(@website_html)
    end
  end

  def test1
    p = BandcampMerchTest.create do
      band "dancewiththedead"
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 14
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" => "http://dancewiththedead.bandcamp.com/merch/spider-circle-logo-t-shirt",
      "img_src" => "https://f4.bcbits.com/img/0039849078_37.jpg",
      "title" => "Spider Circle Logo T-Shirt ",
      "url" =>
  "http://dancewiththedead.bandcamp.com/merch/spider-circle-logo-t-shirt"
    }
  end
end
