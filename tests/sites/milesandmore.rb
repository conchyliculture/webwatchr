require "test/unit"
require_relative "../helpers"
require_relative "../../lib/sites/milesandmore"

class MilesAndMoreTests < ArticleSiteTest
  class MilesAndMoreTest < MilesAndMore
    def pull_things
      @website_html = File.read(File.join(__dir__, "data/milesandmore.json"))
    end
  end

  def test_default
    p = MilesAndMoreTest.create
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal({
                   "id" => "https://www.miles-and-more.com/ch/fr/spend/eurowings/air-offer/mileage-bargains/10/ew/economy/2026-11-15-2026-12-31/12000/28000/cologne-bonn.html",
                   "url" => "https://www.miles-and-more.com/ch/fr/spend/eurowings/air-offer/mileage-bargains/10/ew/economy/2026-11-15-2026-12-31/12000/28000/cologne-bonn.html",
                   "title" => "Eurowings economy | ZRH → Cologne/Bonn (CGN) | 12'000 miles (was 28'000, -57%) | travel 2026-11-15 → 2026-12-31 | book by 2026-10-31"
                 }, first_result)
  end

  def test_filters
    p = MilesAndMoreTest.create do
      country nil
      from "VIE"
      max_miles 12_000
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert(alert.result.all? { |a| a["title"].include?("VIE") })
    assert(alert.result.none? { |a| a["title"].include?("ZRH") })
  end
end
