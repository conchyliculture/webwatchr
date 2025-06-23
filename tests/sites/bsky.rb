require "test/unit"
require_relative "../helpers"
require_relative "../../lib/sites/bsky"

class BskyTests < ArticleSiteTest
  class BskyAccountTest < BskyAccount
    def pull_things
      @parsed_json = JSON.parse(File.read(File.join(__dir__, "data/bsky_account")))
    end
  end

  class BskySearchTest < BskySearch
    def pull_things
      @parsed_json = JSON.parse(File.read(File.join(__dir__, "data/bsky_search")))
    end
  end

  def test_account
    p = BskyAccountTest.create do
      account "theonion.com"
    end
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 29
    first_result = alert.result[0]
    first_result.delete("_timestamp")
    assert_equal first_result, {
      "id" =>
  "at://did:plc:a4pqq234yw7fqbddawjo7y35/app.bsky.feed.post/3lr7lkkxazk2p",
      "title" =>
  "2025-06-10T00:00:00.000Z: “We’re requiring all men to head to their doctors and have them undo these terrible, terrible procedures,” the president said in an address from the Oval Office\n" +
  "theonion.com/trump-i...",
      "url" => "https://bsky.app/profile/theonion.com/post/3lr7lkkxazk2p"
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
  "at://did:plc:a4pqq234yw7fqbddawjo7y35/app.bsky.feed.post/3lr7lkkxazk2p",
      "title" =>
  "2025-06-10T00:00:00.000Z: “We’re requiring all men to head to their doctors and have them undo these terrible, terrible procedures,” the president said in an address from the Oval Office\n" +
  "theonion.com/trump-i...",
      "url" => "https://bsky.app/profile/theonion.com/post/3lr7lkkxazk2p"
    }
  end

  def test_regex
    p = BskyAccountTest.new
    p.account("theonion.com")
    p.set("regex", /christ/i)
    alert = TestAlerter.new()
    p.alerters = [alert]
    fakeupdate(p)

    assert_equal alert.result.size, 1
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
