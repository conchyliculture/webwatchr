require "test/unit"
require_relative "../helpers"
require_relative "../../lib/sites/bsky"

class BskyTests < ArticleSiteTest
  class BskyAccountTest < BskyAccount
    def pull_things
      @parsed_content = JSON.parse(File.read(File.join(__dir__, "data/bsky_account")))
    end
  end

  class BskySearchTest < BskySearch
    def pull_things
      @parsed_content = JSON.parse(File.read(File.join(__dir__, "data/bsky_search")))
    end
  end

  def test_account
    p = BskyAccountTest.create do
      account "theonion.com"
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 30
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" =>
  "at://did:plc:a4pqq234yw7fqbddawjo7y35/app.bsky.feed.post/3lqy25osxdq2h",
      "title" =>
  "2025-06-07T00:00:02.000Z: “Boys, your father wanted me to tell you that you won’t be seeing your Uncle Elon anymore because he is now in a million pieces,” said Susie Wiles theonion.com/weeping...",
      "url" => "https://bsky.app/profile/theonion.com/post/3lqy25osxdq2h"
    }
  end

  def test_no_repost
    p = BskyAccountTest.new
    p.account("theonion.com")
    p.set("reposts", false)
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 29
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" =>
  "at://did:plc:a4pqq234yw7fqbddawjo7y35/app.bsky.feed.post/3lqxyhy34wm2c",
      "title" =>
  "2025-06-06T23:30:00.000Z: “Ever since Christ was executed in broad daylight in the middle of Golgotha, questions have swirled about the mysterious circumstances surrounding his death, but no longer,” said the Bishop Of Rome theonion.com/new-pop...",
      "url" => "https://bsky.app/profile/theonion.com/post/3lqxyhy34wm2c"
    }
  end

  def test_regex
    p = BskyAccount.new
    p.account("theonion.com")
    p.set("regex", /christ/i)
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 3
  end

  def test_search
    p = BskySearchTest.create do
      keyword "#danemark"
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 30
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" =>
             "at://did:plc:yo6tbxdh7m5orf6y7y6hjh4b/app.bsky.feed.post/3lqkvlt7tuc2t",
      "title" =>
             "2025-06-01T18:33:51.836Z: Le «Circle Bridge» est une passerelle piétonne et cyclable située en plein cœur de Copenhague, au #Danemark. 🇩🇰",
      "url" => "https://bsky.app/profile//post/3lqkvlt7tuc2t"
    }
  end
end
