require "logger"
require "test/unit"

class TwitterTest < Test::Unit::TestCase
  require_relative "../../sites-available/twitter.rb"

  def testContent
    expected_results = [
      {"id"=>"https://twitter.com/mobile_test_2/status/701965509349154816",
       "url"=>"https://twitter.com/mobile_test_2/status/701965509349154816",
       "img_src"=>nil,
       "title"=>"Test test"},
      {"id"=>"https://twitter.com/mobile_test_2/status/603018949316354048",
       "url"=>"https://twitter.com/mobile_test_2/status/603018949316354048",
       "img_src"=>nil,
       "title"=>"Testing testing one two three."},
      {"id"=>"https://twitter.com/mobile_test_2/status/602949806273638400",
       "url"=>"https://twitter.com/mobile_test_2/status/602949806273638400",
       "img_src"=>nil, "title"=>"Testing one two three four."},
      {"id"=>"https://twitter.com/mobile_test_2/status/517497730743009280",
       "url"=>"https://twitter.com/mobile_test_2/status/517497730743009280",
       "img_src"=>nil, "title"=>"test testes te\n" + "\n" + "fdsfseoifj"},
      {"id"=>"https://twitter.com/mobile_test_2/status/517478338017775616",
       "url"=>"https://twitter.com/mobile_test_2/status/517478338017775616",
       "img_src"=>nil, "title"=>"Testing one two three four."},
      {"id"=>"https://twitter.com/mobile_test_2/status/517449200045277184",
       "url"=>"https://twitter.com/mobile_test_2/status/517449200045277184",
       "img_src"=>nil, "title"=>"Testing. One two three four. Test."},
      {"id"=>"https://twitter.com/mobile_test_2/status/401092834217832448",
       "url"=>"https://twitter.com/mobile_test_2/status/401092834217832448",
       "img_src"=>nil, "title"=>"@mobile_test_3 Test again."},
      {"id"=>"https://twitter.com/mobile_test_2/status/401092735429398528",
       "url"=>"https://twitter.com/mobile_test_2/status/401092735429398528",
       "img_src"=>nil, "title"=>"@mobile_test_3 Testing reply test."},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091567999397889",
       "url"=>"https://twitter.com/mobile_test_2/status/401091567999397889",
       "img_src"=>nil, "title"=>"@mobile_test_3 Test reply 3."},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091532138102784",
       "url"=>"https://twitter.com/mobile_test_2/status/401091532138102784",
       "img_src"=>nil, "title"=>"@mobile_test_3 Test reply 2."},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091502157230080",
       "url"=>"https://twitter.com/mobile_test_2/status/401091502157230080",
       "img_src"=>nil, "title"=>"@mobile_test_3 Test reply."},
      {"id"=>"https://twitter.com/mobile_test/status/400504880327954433",
       "url"=>"https://twitter.com/mobile_test/status/400504880327954433",
       "img_src"=>nil, "title"=>"Testing. 1234."},
      {"id"=>"https://twitter.com/mobile_test_2/status/398528424886558721",
       "url"=>"https://twitter.com/mobile_test_2/status/398528424886558721",
       "img_src"=>nil, "title"=>"Test test test."},
      {"id"=>"https://twitter.com/mobile_test_2/status/398528393072742402",
       "url"=>"https://twitter.com/mobile_test_2/status/398528393072742402",
       "img_src"=>nil, "title"=>"Testing."},
      {"id"=>"https://twitter.com/mobile_test_2/status/395975667008819200",
       "url"=>"https://twitter.com/mobile_test_2/status/395975667008819200",
       "img_src"=>nil, "title"=>"Test"},
      {"id"=>"https://twitter.com/EmergencyPuppy/status/393809245084590080",
       "url"=>"https://twitter.com/EmergencyPuppy/status/393809245084590080",
       "img_src"=>nil, "title"=>"Wolf pup, on the prowl"},
      {"id"=>"https://twitter.com/mobile_test_2/status/385421581708967936",
       "url"=>"https://twitter.com/mobile_test_2/status/385421581708967936",
       "img_src"=>nil, "title"=>"12345."},
      {"id"=>"https://twitter.com/mobile_test_2/status/385407139856257024",
       "url"=>"https://twitter.com/mobile_test_2/status/385407139856257024",
       "img_src"=>nil, "title"=>"1234."},
      {"id"=>"https://twitter.com/mobile_test_2/status/381158773399646209",
       "url"=>"https://twitter.com/mobile_test_2/status/381158773399646209",
       "img_src"=>nil, "title"=>"2."},
      {"id"=>"https://twitter.com/mobile_test_2/status/381123354515615744",
       "url"=>"https://twitter.com/mobile_test_2/status/381123354515615744",
       "img_src"=>nil, "title"=>"1."}]

    logger = Logger.new(STDOUT)
    logger.level = Logger::ERROR
    t = Twitter.new(account:"mobile_test_2", test:true)
    t.logger = logger
    t.pull_things()
    results = t.get_new([])
    assert {results.map{|x| x.reject{|k,v| k == "_timestamp"}} == expected_results}
  end
end
