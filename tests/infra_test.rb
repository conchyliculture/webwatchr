#!/usr/bin/ruby
require "fileutils"
require "logger"
require_relative "../lib/webwatchr/site"
require_relative "./helpers"
require "tmpdir"
require "test/unit"

class BaseWebrickTest < Test::Unit::TestCase
  require "webrick"

  TEST_CONFIG = {
    wwwroot: File.join(File.dirname(__FILE__), "www-root"),
    wwwport: 8001,
    content_is_string_file: "content_is_string.html",
    content_is_array_file: "content_is_array.html"
  }.freeze

  class TestFileHandler < WEBrick::HTTPServlet::FileHandler
    def do_GET(req, res) # rubocop:disable Metrics/MethodName
      res.status = 200
      res["Content-Encoding"] = "utf-8"
      res["Content-Type"] = "text/html; charset=utf-8"
      res.body = File.open(File.join(TEST_CONFIG[:wwwroot], req.path)).read()
    end
  end

  def restart_webrick()
    @webrick = WEBrick::HTTPServer.new(
      AccessLog: [],
      Logger: WEBrick::Log.new("/dev/null", 7),
      Port: TEST_CONFIG[:wwwport]
    )
    @webrick.mount("/", TestFileHandler, TEST_CONFIG[:wwwroot])

    @serv_thread = Thread.new do
      @webrick.start
    end
  end

  def setup
    @workdir = Dir.mktmpdir
    @logger_test_io = StringIO.new()
    MyLog.instance.configure(@logger_test_io, nil, Logger::DEBUG)
    restart_webrick()
  end

  def cleanup
    FileUtils.remove_entry_secure(@workdir) if File.directory?(@workdir)
  end

  def teardown()
    @webrick.stop
    @serv_thread.join
    [TEST_CONFIG[:content_is_string_file], TEST_CONFIG[:content_is_array_file]].each do |tf|
      File.open(File.join(TEST_CONFIG[:wwwroot], tf), "w") do |f|
        f.puts ""
      end
    end
  end
end

class TestResultObjects < BaseWebrickTest
  class TestStringList < Site::SimpleString
    def extract_content()
      res = Site::SimpleString::ListResult.new
      res << "first string"
      res << "second string"
      return res
    end
  end

  def test_list_result
    url = "http://localhost:#{TEST_CONFIG[:wwwport]}/#{TEST_CONFIG[:content_is_string_file]}"

    c = TestStringList.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    assert { c.load_state_file() == {} }
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    c.state_file = File.join(last_dir, "last-localhost-2182cd5c8685baed48f692ed72d7a89f")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    first_pass_content = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n<ul>\n<li>first string</li>\n<li>second string</li>\n</ul>"
    assert { c.generate_html_content == first_pass_content }
    first_pass_content_telegram = [" * first string\n * second string"]
    assert { c.generate_telegram_message_pieces == first_pass_content_telegram }
    assert { a.result.message == c.content.message }
  end
end

class TestSimpleStringSite < BaseWebrickTest
  class TestStringSite < Site::SimpleString
    def initialize
      super()
      @update_interval = 200
    end

    def extract_content()
      return ResultObject.new(@parsed_html.css("div.content").text)
    end
  end

  def test_content_is_string
    content_html = "👌 👌 👌 💯 💯 💯 💯 -KYop-R11Iqo.mp"
    whole_html = Site::HTML_HEADER.dup
    whole_html += "<title>test</title><div class='content'>#{content_html}</div>"
    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_string_file]), "w") do |f|
      f.write whole_html
    end
    url = "http://localhost:#{TEST_CONFIG[:wwwport]}/#{TEST_CONFIG[:content_is_string_file]}"

    # First pull, there is new stuff to see
    c = TestStringSite.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    assert { c.load_state_file() == {} }
    html = c.fetch_url(url)
    assert { whole_html == html }
    assert { c.parse_noko(html).css("title").text == "test" }
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    c.state_file = File.join(last_dir, "last-localhost-2182cd5c8685baed48f692ed72d7a89f")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "DEBUG -- TestSimpleStringSite::TestStringSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    first_pass_content = Site::HTML_HEADER + content_html
    assert { c.generate_html_content == first_pass_content }
    assert { a.result.message == c.content.message }

    # Second pull, there is new stuff to see, but we haven't waited long enough
    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_string_file]), "w+") do |f|
      f.write whole_html.gsub("</div>", " new ! </div>")
    end
    c = TestStringSite.new
    c.url = url
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    result_last = JSON.parse(File.read(c.state_file), create_additions: true)
    assert { result_last['time'] == Time.now.to_i }
    c.comment = "lol"
    expected_error = "INFO -- TestSimpleStringSite::TestStringSite: Too soon to update #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { c.content.nil? }
    assert { c.generate_html_content.nil? }
    assert { c.name == url }

    # Third pull, there is new stuff to see, and we have waited long enough
    now_minus_some = Time.now.to_i - 300
    c.update_state_file({ "time" => now_minus_some })
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "DEBUG -- TestSimpleStringSite::TestStringSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { c.content.to_html == "#{content_html} new ! " }
    assert { c.generate_html_content == "#{first_pass_content} new ! " }
    assert { c.name == url }
    result_last = JSON.parse(File.read(c.state_file), create_additions: true)
    assert { result_last['time'] == Time.now.to_i }
    assert { result_last["content"].message == "#{content_html} new ! " }
    assert { result_last["wait_at_least"] == 200 }

    # 4th pull, there is no new stuff to see, and we have waited long enough
    now_minus_some = Time.now.to_i - 300
    c.update_state_file({ "time" => now_minus_some })
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "INFO -- TestSimpleStringSite::TestStringSite: Nothing new for #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { c.content.to_html == "#{content_html} new ! " }
    assert { c.generate_html_content == "#{first_pass_content} new ! " }
    assert { c.name == url }
    result_last = JSON.parse(File.read(c.state_file), create_additions: true)
    assert { result_last['time'] == Time.now.to_i }
    assert { result_last["content"].message == "#{content_html} new ! " }
    assert { result_last["wait_at_least"] == 200 }
  ensure
    cleanup
  end
end

class TestArraySites < BaseWebrickTest
  class TestArraySite < Site::Articles
    def initialize
      super()
      @update_interval = 200
    end

    def extract_articles()
      res = []
      @parsed_html.css("div").each do |x|
        a, b = x.text.split("-").map(&:strip)
        add_article(Article["id" => a, "url" => a, "title" => b])
      end
      return res
    end
  end

  def test_content_is_array
    whole_html = "#{Site::HTML_HEADER.dup}<title>test</title>👌 👌 👌 💯 💯 💯 💯 -KYop-R11Iqo.mp4<div> lol - lilo</div> <div> fi - fu</div>"
    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_array_file]), "w") do |f|
      f.write whole_html
    end
    url = "http://localhost:#{TEST_CONFIG[:wwwport]}/#{TEST_CONFIG[:content_is_array_file]}"

    c = TestArraySite.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    assert { c.load_state_file() == {} }
    html = c.fetch_url(url)
    assert { html == whole_html }
    assert { c.parse_noko(html).css("title").text == "test" }

    # First full run, Get 2 things
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    assert { c.state_file.end_with?("last-localhost-35e711989b197f20f3d4936e91a2c079") }
    expected_error = "DEBUG -- TestArraySites::TestArraySite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1].strip()
    assert { last_error.end_with?(expected_error) }
    expected_html = Site::HTML_HEADER.dup + [
      "<ul style='list-style-type: none;'>",
      "<li id='lol'><a href='lol'>lilo</a></li>",
      "<li id='fi'><a href='fi'>fu</a></li>",
      "</ul>"
    ].join("\n")
    c.articles.each { |x| x.delete('_timestamp') }
    assert {
      c.articles == [
        { "id" => "lol", "url" => "lol", "title" => "lilo" },
        { "id" => "fi", "url" => "fi", "title" => "fu" }
      ]
    }
    assert { c.generate_html_content == expected_html }

    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_array_file]), "a+") do |f|
      f.write "<div>new! - new </div>"
    end
    c = TestArraySite.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    # Second run don't do anything because we shouldn't rerun
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "INFO -- TestArraySites::TestArraySite: Too soon to update #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }

    c.update_state_file({ "time" => Time.now.to_i - 300 })

    # This time we set new things, and wait is 0 so we are good to go
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "DEBUG -- TestArraySites::TestArraySite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }

    expected_html = Site::HTML_HEADER.dup + [
      "<ul style='list-style-type: none;'>",
      "<li id='new!'><a href='new!'>new</a></li>",
      "</ul>"
    ].join("\n")

    c.articles.each { |x| x.delete('_timestamp') }
    assert { c.articles == [{ "id" => "new!", "url" => "new!", "title" => "new" }] }
    assert { c.generate_html_content == expected_html }
    expected_last = {
      "wait_at_least" => 200,
      "articles" => [{ "id" => "lol", "title" => "lilo", "url" => "lol" },
                     { "id" => "fi", "title" => "fu", "url" => "fi" },
                     { "id" => "new!", "title" => "new", "url" => "new!" }]
    }
    result_last = JSON.parse(File.read(c.state_file))
    result_last.delete("time")
    result_last["articles"].each do |article|
      article.delete("_timestamp")
    end
    assert { expected_last == result_last }

    result = ""

    c = TestArraySite.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    # Now, we don't call the alerters because we have no new things
    c.state_file = File.join(last_dir, "last-localhost-35e711989b197f20f3d4936e91a2c079")
    c.update_state_file({ "time" => Time.now.to_i - 300 })
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "INFO -- TestArraySites::TestArraySite: Nothing new for #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    expected_html = Site::HTML_HEADER.dup + [
      "<ul style=\"list-style-type: none;\">",
      "</ul>"
    ].join("\n")
    assert { result == "" }
  ensure
    cleanup
  end
end

class TestDiffStringSite < BaseWebrickTest
  class TestDiffSite < Site::DiffString
    def initialize
      super()
      @update_interval = 0
    end

    def extract_content()
      return ResultObject.new(@parsed_html.css("div.content").text)
    end
  end

  def test_content_is_string
    content_html = "Line1\nLine2\nLine3"
    whole_html = Site::HTML_HEADER.dup
    whole_html += "<title>test</title><div class='content'>#{content_html}</div>"
    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_string_file]), "w") do |f|
      f.write whole_html
    end
    url = "http://localhost:#{TEST_CONFIG[:wwwport]}/#{TEST_CONFIG[:content_is_string_file]}"

    # First pull, there is new stuff to see
    c = TestDiffSite.new
    c.url = url
    a = TestAlerter.new()
    c.alerters = [a]
    assert { c.load_state_file() == {} }
    html = c.fetch_url(url)
    assert { whole_html == html }
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    c.state_file = File.join(last_dir, "last-localhost-2182cd5c8685baed48f692ed72d7a89f")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    expected_error = "DEBUG -- TestDiffStringSite::TestDiffSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]

    assert { last_error.end_with?(expected_error) }
    begin
      require "diffy"
      first_pass_content = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n<head><style>.diff{overflow:auto;}\n.diff ul{background:#fff;overflow:auto;font-size:13px;list-style:none;margin:0;padding:0;display:table;width:100%;}\n.diff del, .diff ins{display:block;text-decoration:none;}\n.diff li{padding:0; display:table-row;margin: 0;height:1em;}\n.diff li.ins{background:#dfd; color:#080}\n.diff li.del{background:#fee; color:#b00}\n.diff li:hover{background:#ffc}\n/* try 'whitespace:pre;' if you don't want lines to wrap */\n.diff del, .diff ins, .diff span{white-space:pre-wrap;font-family:courier;}\n.diff del strong{font-weight:normal;background:#fcc;}\n.diff ins strong{font-weight:normal;background:#9f9;}\n.diff li.diff-comment { display: none; }\n.diff li.diff-block-info { background: none repeat scroll 0 0 gray; }\n</style><body><div class=\"diff\">\n  <ul>\n    <li class=\"ins\"><ins>Line1</ins></li>\n    <li class=\"ins\"><ins>Line2</ins></li>\n    <li class=\"ins\"><ins>Line3</ins></li>\n  </ul>\n</div>\n</body></html>"
      assert { c.generate_html_content == first_pass_content }
    rescue LoadError
      first_pass_content = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n---\n+++\n@@ -1,0 +1,3 @@ Line1\n+Line1\n+Line2\n+Line3</body></html>"
      assert { c.generate_html_content == first_pass_content }
    end
    assert { a.result.message == c.content.message }

    # Second pull, there is new stuff to see
    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_string_file]), "w+") do |f|
      f.write whole_html.gsub(content_html, "#{content_html}\nLine4!")
    end
    c = TestDiffSite.new
    c.url = url
    cache_dir = File.join(@workdir, "cache")
    last_dir = File.join(@workdir, ".lasts")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    c.update(cache_dir: cache_dir, last_dir: last_dir)
    result_last = JSON.parse(File.read(c.state_file), create_additions: true)
    assert { result_last['time'] == Time.now.to_i }
    c.comment = "lol"
    expected_error = "DEBUG -- TestDiffStringSite::TestDiffSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    begin
      require "diffy"
      first_pass_content = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n<head><style>.diff{overflow:auto;}\n.diff ul{background:#fff;overflow:auto;font-size:13px;list-style:none;margin:0;padding:0;display:table;width:100%;}\n.diff del, .diff ins{display:block;text-decoration:none;}\n.diff li{padding:0; display:table-row;margin: 0;height:1em;}\n.diff li.ins{background:#dfd; color:#080}\n.diff li.del{background:#fee; color:#b00}\n.diff li:hover{background:#ffc}\n/* try 'whitespace:pre;' if you don't want lines to wrap */\n.diff del, .diff ins, .diff span{white-space:pre-wrap;font-family:courier;}\n.diff del strong{font-weight:normal;background:#fcc;}\n.diff ins strong{font-weight:normal;background:#9f9;}\n.diff li.diff-comment { display: none; }\n.diff li.diff-block-info { background: none repeat scroll 0 0 gray; }\n</style><body><div class=\"diff\">\n  <ul>\n    <li class=\"unchanged\"><span>Line1</span></li>\n    <li class=\"unchanged\"><span>Line2</span></li>\n    <li class=\"del\"><del>Line3</del></li>\n    <li class=\"ins\"><ins>Line3</ins></li>\n    <li class=\"ins\"><ins><strong>Line4!</strong></ins></li>\n    <li class=\"ins\"><ins><strong></strong></ins></li>\n  </ul>\n</div>\n</body></html>"
      assert { c.generate_html_content == first_pass_content }
    rescue LoadError
      first_pass_content = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n---\n+++\n@@ -1,3 +1,4 @@ Line1\n Line1\n Line2\n Line3\n+Line4!</body></html>"
      assert { c.generate_html_content == first_pass_content }
    end
  ensure
    cleanup
  end
end

class TestImages < BaseWebrickTest
  require "mechanize"

  # 1x1 PNG, not valid UTF-8, to make sure we don't mangle binary data
  PNG = ["89504e470d0a1a0a0000000d4948445200000001000000010806000000" \
         "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"].pack("H*")

  class FakeTelegramApi
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send_message(**args)
      @calls << [:message, args]
    end

    def send_photo(**args)
      @calls << [:photo, args]
    end
  end

  class TestImageArticles < Site::Articles
    def extract_articles()
      add_article(Article["id" => "a", "url" => "http://a", "title" => "with pic", "img_src" => "#{@url}pic.png"])
      add_article(Article["id" => "b", "url" => "http://b", "title" => "no pic"])
    end
  end

  # Pictures are only available after logging in, which sets a cookie in @mechanize
  class TestLoginArticles < Site::Articles
    def pull_things()
      @mechanize = Mechanize.new
      @mechanize.get("#{@url}login")
    end

    def extract_articles()
      add_article(Article["id" => "a", "title" => "private", "img_src" => "#{@url}private.png"])
    end
  end

  # Pictures need a token we only have in the Site
  class TestTokenArticles < TestImageArticles
    def fetch_image(url)
      return nil unless url.end_with?("pic.png")

      return { data: "token-#{url}", content_type: "image/png" }
    end
  end

  def setup
    super
    @webrick.mount_proc("/pic.png") do |_req, res|
      res["Content-Type"] = "image/png"
      res.body = PNG
    end
    @webrick.mount_proc("/redir") do |_req, res|
      res.set_redirect(WEBrick::HTTPStatus::Found, "/pic.png")
    end
    @webrick.mount_proc("/login") do |_req, res|
      res.cookies << WEBrick::Cookie.new("session", "s3cr3t")
      res["Content-Type"] = "text/html"
      res.body = "logged in"
    end
    @webrick.mount_proc("/private.png") do |req, res|
      if req.cookies.any? { |c| c.name == "session" && c.value == "s3cr3t" }
        res["Content-Type"] = "image/png"
        res.body = PNG
      else
        res.status = 403
      end
    end
    @base = "http://localhost:#{TEST_CONFIG[:wwwport]}/"
  end

  def make_site(klass = TestImageArticles)
    c = klass.new
    c.url = @base
    c.pull_things if klass == TestLoginArticles
    c.extract_articles
    return c
  end

  # Replaces klass.meth with the block for the duration of yield
  def stubbing(klass, meth, impl)
    orig = klass.method(meth)
    klass.define_singleton_method(meth, &impl)
    yield
  ensure
    klass.define_singleton_method(meth, orig)
  end

  def test_fetch_images
    c = make_site
    assert { c.image_urls == ["#{@base}pic.png"] }
    c.fetch_images
    assert { c.image("#{@base}pic.png") == { data: PNG, content_type: "image/png", filename: "pic.png" } }

    assert { c.fetch_image("#{@base}redir")[:data] == PNG }
    # Not an image, or not reachable: not kept
    c.add_article(Site::Articles::Article["id" => "c", "title" => "html", "img_src" => "#{@base}#{TEST_CONFIG[:content_is_string_file]}"])
    c.add_article(Site::Articles::Article["id" => "d", "title" => "down", "img_src" => "http://localhost:1/nope.png"])
    c.fetch_images
    assert { c.image("#{@base}#{TEST_CONFIG[:content_is_string_file]}").nil? }
    assert { c.image("http://localhost:1/nope.png").nil? }
  end

  def test_fetch_images_with_login
    # Without the session, we can't get the picture
    anonymous = make_site(TestImageArticles)
    assert { anonymous.fetch_image("#{@base}private.png").nil? }

    c = make_site(TestLoginArticles)
    c.fetch_images
    assert { c.image("#{@base}private.png")[:data] == PNG }
  end

  def test_fetch_images_overridden
    c = make_site(TestTokenArticles)
    c.fetch_images
    assert { c.image("#{@base}pic.png") == { data: "token-#{@base}pic.png", content_type: "image/png", filename: "pic.png" } }
  end

  def test_add_image
    c = make_site
    c.add_image("#{@base}pic.png", "already there", "image/jpeg")
    # Not downloaded again
    c.fetch_images
    assert { c.image("#{@base}pic.png")[:data] == "already there" }
  end

  def test_add_article_with_image
    c = TestImageArticles.new
    c.url = @base
    # No img_src: the picture only lives in memory
    c.add_article(Site::Articles::Article["id" => "a b", "title" => "attached"], image: PNG)
    # With img_src: the picture is used for it, instead of downloading it
    c.add_article(Site::Articles::Article["id" => "c", "title" => "known", "img_src" => "http://localhost:1/c.jpg"], image: "\xFF\xD8\xFFjpeg")
    # Unknown type: no picture
    c.add_article(Site::Articles::Article["id" => "d", "title" => "garbage"], image: "garbage")

    attached = "webwatchr-image://a+b"
    assert { c.image(attached) == { data: PNG, content_type: "image/png", filename: "image.png" } }
    assert { c.image("http://localhost:1/c.jpg")[:content_type] == "image/jpeg" }
    assert { c.articles.none? { |art| art.values.include?(PNG) } }
    assert {
      c.generate_telegram_message_pieces == [
        Site::Image.new(attached, caption: "attached"),
        Site::Image.new("http://localhost:1/c.jpg", caption: "known"),
        "garbage"
      ]
    }
    assert { c.image_urls == [attached, "http://localhost:1/c.jpg"] }
    c.fetch_images
    assert { c.image("http://localhost:1/c.jpg")[:data] == "\xFF\xD8\xFFjpeg".b }

    _html, images = Webwatchr::Alerting::EmailAlert.new.inline_images(c, c.generate_html_content)
    assert { images.values.map { |i| i[:content_type] } == ["image/png", "image/jpeg"] }
  end

  def test_telegram_pieces
    c = make_site
    assert {
      c.generate_telegram_message_pieces == [
        Site::Image.new("#{@base}pic.png", caption: "with pic: http://a"),
        "no pic: http://b"
      ]
    }

    s = Site::SimpleString.new
    res = Site::SimpleString::ListResult.new("one")
    res.images = ["http://x/1.png"]
    s.set(:content, res)
    assert { s.generate_telegram_message_pieces == [" * one", Site::Image.new("http://x/1.png")] }
    assert { s.generate_html_content.end_with?("</ul>\n<img style='width:100px' src='http://x/1.png'/>") }
    assert { s.image_urls == ["http://x/1.png"] }
    # Images don't change the result identity
    assert { res == Site::SimpleString::ListResult.new("one") }
  end

  def test_email_inline_images
    c = make_site
    c.fetch_images
    html = "<img src='#{@base}pic.png'/><img src=\"#{@base}pic.png\"><img src='http://localhost:1/broken.png'/>"
    alert = Webwatchr::Alerting::EmailAlert.new
    new_html, images = alert.inline_images(c, html)
    assert { images.size == 1 }
    cid = images.keys.first
    assert { new_html == "<img src='cid:#{cid}'/><img src=\"cid:#{cid}\"><img src='http://localhost:1/broken.png'/>" }

    sent = nil
    fake_smtp = Object.new
    fake_smtp.define_singleton_method(:send_message) { |msg, _from, _to| sent = msg }
    alert.set(:from_addr, "a@b").set(:dest_addr, "c@d").set(:smtp_server, "localhost").set(:smtp_port, 25)
    c = make_site
    c.alerters = [alert]
    stubbing(Net::SMTP, :start, proc { |*_args, **_kw, &blk| blk.call(fake_smtp) }) do
      c.alert
    end
    assert { sent =~ %r{Content-Type: multipart/related; boundary="(webwatchr-\h+)"} }
    boundary = Regexp.last_match(1)
    assert { sent.end_with?("--#{boundary}--\n") }
    assert { sent =~ /Content-ID: <(.+)>/ }
    assert { sent.include?("src='cid:#{Regexp.last_match(1)}'") }
    assert { sent.include?([PNG].pack("m")) }
  end

  def test_telegram_alert
    c = make_site
    api = FakeTelegramApi.new
    bot = Struct.new(:api).new(api)
    c.alerters = [Webwatchr::Alerting::TelegramAlert.new.set(:token, "t").set(:chat_id, 1)]
    stubbing(Telegram::Bot::Client, :new, proc { |*_args| bot }) do
      c.alert
    end
    assert { api.calls.map(&:first) == %i[message photo message] }
    assert { api.calls[0][1][:text] == "#{c.get_email_subject}\n#{@base}\n" }
    photo = api.calls[1][1]
    assert { photo[:caption] == "with pic: http://a" }
    assert { photo[:photo].read == PNG }
    assert { api.calls[2][1][:text] == "no pic: http://b\n" }
  end

  def test_telegram_alert_without_downloaded_picture
    c = make_site
    api = FakeTelegramApi.new
    bot = Struct.new(:api).new(api)
    alert = Webwatchr::Alerting::TelegramAlert.new.set(:token, "t").set(:chat_id, 1)
    # Calling the alerter directly: nothing was downloaded, and the alerter doesn't download
    stubbing(Telegram::Bot::Client, :new, proc { |*_args| bot }) do
      alert.alert(c)
    end
    assert { api.calls.map(&:first) == %i[message message message] }
    assert { api.calls[1][1][:text] == "with pic: http://a\n#{@base}pic.png\n" }
  end
end
