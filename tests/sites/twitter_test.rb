require "logger"
require "test/unit"

class TwitterTest < Test::Unit::TestCase
  require_relative "../../sites-available/twitter.rb"

  def testContent
    expected_results = [
      {"id"=>"https://twitter.com/mobile_test_2/status/701965509349154816", "url"=>"https://twitter.com/mobile_test_2/status/701965509349154816", "img_src"=>nil, "title"=>"Test test", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/603018949316354048", "url"=>"https://twitter.com/mobile_test_2/status/603018949316354048", "img_src"=>nil, "title"=>"Testing testing one two three.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/602949806273638400", "url"=>"https://twitter.com/mobile_test_2/status/602949806273638400", "img_src"=>nil, "title"=>"Testing one two three four.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/517497730743009280", "url"=>"https://twitter.com/mobile_test_2/status/517497730743009280", "img_src"=>nil, "title"=>"test testes te\n\nfdsfseoifj", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/517478338017775616", "url"=>"https://twitter.com/mobile_test_2/status/517478338017775616", "img_src"=>nil, "title"=>"Testing one two three four.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/517449200045277184", "url"=>"https://twitter.com/mobile_test_2/status/517449200045277184", "img_src"=>nil, "title"=>"Testing. One two three four. Test.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/401092834217832448", "url"=>"https://twitter.com/mobile_test_2/status/401092834217832448", "img_src"=>nil, "title"=>"@mobile_test_3 Test again.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/401092735429398528", "url"=>"https://twitter.com/mobile_test_2/status/401092735429398528", "img_src"=>nil, "title"=>"@mobile_test_3 Testing reply test.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091567999397889", "url"=>"https://twitter.com/mobile_test_2/status/401091567999397889", "img_src"=>nil, "title"=>"@mobile_test_3 Test reply 3.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091532138102784", "url"=>"https://twitter.com/mobile_test_2/status/401091532138102784", "img_src"=>nil, "title"=>"@mobile_test_3 Test reply 2.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/401091502157230080", "url"=>"https://twitter.com/mobile_test_2/status/401091502157230080", "img_src"=>nil, "title"=>"@mobile_test_3 Test reply.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test/status/400504880327954433", "url"=>"https://twitter.com/mobile_test/status/400504880327954433", "img_src"=>nil, "title"=>"Testing. 1234.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/398528424886558721", "url"=>"https://twitter.com/mobile_test_2/status/398528424886558721", "img_src"=>nil, "title"=>"Test test test.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/398528393072742402", "url"=>"https://twitter.com/mobile_test_2/status/398528393072742402", "img_src"=>nil, "title"=>"Testing.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/395975667008819200", "url"=>"https://twitter.com/mobile_test_2/status/395975667008819200", "img_src"=>nil, "title"=>"Test", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/EmergencyPuppy/status/393809245084590080", "url"=>"https://twitter.com/EmergencyPuppy/status/393809245084590080", "img_src"=>nil, "title"=>"Wolf pup, on the prowl http://t.co/6uFI4z3Js5", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/385421581708967936", "url"=>"https://twitter.com/mobile_test_2/status/385421581708967936", "img_src"=>nil, "title"=>"12345.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/385407139856257024", "url"=>"https://twitter.com/mobile_test_2/status/385407139856257024", "img_src"=>nil, "title"=>"1234.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/381158773399646209", "url"=>"https://twitter.com/mobile_test_2/status/381158773399646209", "img_src"=>nil, "title"=>"2.", "_timestamp"=>1691664883},
      {"id"=>"https://twitter.com/mobile_test_2/status/381123354515615744", "url"=>"https://twitter.com/mobile_test_2/status/381123354515615744", "img_src"=>nil, "title"=>"1.", "_timestamp"=>1691664883}
    ].map {|x| x.reject{|k,v| k == "_timestamp"}}.sort_by{|h| h['id']}

    logger = Logger.new(STDOUT)
    logger.level = Logger::ERROR
    t = Twitter.new(account:"mobile_test_2", test:true)
    t.logger = logger
    t.pull_things()
    results = t.get_new([]).map {|x| x.reject{|k,v| k == "_timestamp"}}.sort_by{|h| h['id']}
    assert {results.size == expected_results.size}
    assert {results == expected_results}
  end
end
