require "test/unit"
require_relative "../helpers"
require_relative "../../lib/sites/songkick"

class SongkickTests < ArticleSiteTest
  class SongkickTest < Songkick
    def pull_things
      @html_content = File.read(File.join(__dir__, "data/songkick"))
      @parsed_content = Nokogiri::HTML.parse(@html_content)
    end
  end

  def test1
    p = SongkickTest.create do
      full_url "https://www.songkick.com/artists/136816-blind-guardian/calendar"
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 23
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" =>
  "https://www.songkick.com/concerts/42268086-blind-guardian-at-013-poppodium?utm_medium=organic&utm_source=microformat",
      "title" =>
  "2025-08-14T19:00:00: Blind Guardian @ 013 Poppodium at 013 Poppodium Tilburg, Netherlands",
      "url" =>
  "https://www.songkick.com/concerts/42268086-blind-guardian-at-013-poppodium?utm_medium=organic&utm_source=microformat"
    }
  end
end
