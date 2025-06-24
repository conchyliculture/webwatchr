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
