#!/usr/bin/ruby
require "fileutils"
require "logger"
require_relative "../lib/site"
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
    @webwatchr_config = JSON.parse(File.read(File.join(File.dirname(__FILE__), "..", "config.json.template")))
    @webwatchr_config['last_dir'] = Dir.mktmpdir
    Config.set_config(@webwatchr_config)
    FileUtils.mkdir_p(@webwatchr_config["last_dir"])
    @logger_test_io = StringIO.new()
    MyLog.instance.configure(@logger_test_io, nil, Logger::DEBUG)
    restart_webrick()
  end

  def teardown()
    @webrick.stop
    @serv_thread.join
    [TEST_CONFIG[:content_is_string_file], TEST_CONFIG[:content_is_array_file]].each do |tf|
      File.open(File.join(TEST_CONFIG[:wwwroot], tf), "w") do |f|
        f.puts ""
      end
    end
    FileUtils.remove_entry_secure(@webwatchr_config["last_dir"])
  end
end

class TestSimpleStringSite < BaseWebrickTest
  class TestStringSite < Site::SimpleString
    def get_content()
      @parsed_content.css("div.content").text
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
    wait = 10 * 60

    result = {}

    @webwatchr_config["alert_procs"] = { "test" => proc { |x| result = x } }
    Config.set_config(@webwatchr_config)

    c = TestStringSite.new(url: url, comment: "comment")
    assert { c.load_state_file() == {} }
    assert { c.should_update?(-9_999_999_999_999) }
    assert { c.should_update?((Time.now() - wait + 30).to_i) == false }
    html = c.fetch_url(url)
    assert { whole_html == html }
    assert { c.parse_noko(html).css("title").text == "test" }
    assert { c.state_file().end_with?("last-localhost-2182cd5c8685baed48f692ed72d7a89f") }
    c.update()
    expected_error = "DEBUG -- TestSimpleStringSite::TestStringSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    first_pass_content = Site::HTML_HEADER + content_html
    assert { c.content == content_html }
    assert { c.get_html_content == first_pass_content }
    assert { result == { site: c } }

    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_string_file]), "w+") do |f|
      f.write whole_html.gsub("</div>", " new ! </div>")
    end
    c = TestStringSite.new(url: url, comment: "lol")
    c.update()
    expected_error = "INFO -- TestSimpleStringSite::TestStringSite: Too soon to update #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { c.content.nil? }
    assert { c.get_html_content.nil? }
    assert { c.name == url }

    c.wait = 0
    c.update()
    expected_error = "DEBUG -- TestSimpleStringSite::TestStringSite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { c.content == "#{content_html} new ! " }
    assert { c.get_html_content == "#{first_pass_content} new ! " }
    assert { c.name == url }
    result_last = JSON.parse(File.read(c.state_file))
    result_last.delete("time")
    assert { result_last["url"] == url }
    assert { result_last["content"] == "#{content_html} new ! " }
    assert { result_last["wait"] == 0 }
  end
end

class TestArraySites < BaseWebrickTest
  class TestArraySite < Site::Articles
    def get_content()
      res = []
      @parsed_content.css("div").each do |x|
        a, b = x.text.split("-").map(&:strip)
        add_article({ "id" => a, "url" => a, "title" => b })
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
    wait = 10 * 60

    result = {}
    called = false
    @webwatchr_config["alert_procs"] = {
      "test" => proc { |x|
        result = x
        called = true
      }
    }
    Config.set_config(@webwatchr_config)

    c = TestArraySite.new(url: url, every: wait)
    assert { c.load_state_file() == {} }
    assert { c.should_update?(-9_999_999_999_999) }
    assert { !c.should_update?((Time.now() - wait + 30).to_i) }
    html = c.fetch_url(url)
    assert { html == whole_html }
    assert { c.parse_noko(html).css("title").text == "test" }
    assert { c.state_file.end_with?("last-localhost-35e711989b197f20f3d4936e91a2c079") }

    # First full run, Get 2 things
    c.update()
    expected_error = "DEBUG -- TestArraySites::TestArraySite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1].strip()
    assert { last_error.end_with?(expected_error) }
    expected_html = Site::HTML_HEADER.dup + [
      "<ul style='list-style-type: none;'>",
      "<li id='lol'><a href='lol'>lilo</a></li>",
      "<li id='fi'><a href='fi'>fu</a></li>",
      "</ul>"
    ].join("\n")
    c.content.each { |x| x.delete('_timestamp') }
    assert {
      c.content == [
        { "id" => "lol", "url" => "lol", "title" => "lilo" },
        { "id" => "fi", "url" => "fi", "title" => "fu" }
      ]
    }
    assert { c.get_html_content == expected_html }
    assert { called }

    result = ""
    called = false

    File.open(File.join(TEST_CONFIG[:wwwroot], TEST_CONFIG[:content_is_array_file]), "a+") do |f|
      f.write "<div>new! - new </div>"
    end
    c = TestArraySite.new(url: url)
    # Second run don't d anything because we shouldn't rerun
    c.update()
    expected_error = "INFO -- TestArraySites::TestArraySite: Too soon to update #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    assert { !called }
    assert { result == "" }

    result = ""
    called = false

    c.content.each { |x| x.delete('_timestamp') }

    c.wait = 0
    # This time we set new things, and wait is 0 so we are good to go
    c.update()
    expected_error = "DEBUG -- TestArraySites::TestArraySite: Alerting new stuff"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    expected_html = Site::HTML_HEADER.dup + [
      "<ul style='list-style-type: none;'>",
      "<li id='new!'><a href='new!'>new</a></li>",
      "</ul>"
    ].join("\n")
    assert { called }

    c.content.each { |x| x.delete('_timestamp') }
    assert { c.content == [{ "id" => "new!", "url" => "new!", "title" => "new" }] }
    assert { c.get_html_content == expected_html }
    expected_last = { "url" => "http://localhost:#{TEST_CONFIG[:wwwport]}/#{TEST_CONFIG[:content_is_array_file]}",
                      "previous_content" => [{ "id" => "lol", "url" => "lol", "title" => "lilo" },
                                             { "id" => "fi", "url" => "fi", "title" => "fu" }],
                      "wait" => 0,
                      "content" => [{ "id" => "lol", "title" => "lilo", "url" => "lol" },
                                    { "id" => "fi", "title" => "fu", "url" => "fi" },
                                    { "id" => "new!", "title" => "new", "url" => "new!" }] }
    result_last = JSON.parse(File.read(c.state_file))
    result_last.delete("time")
    result_last["content"].each do |item|
      item.delete("_timestamp")
    end
    result_last["previous_content"].each do |item|
      item.delete("_timestamp")
    end
    assert { expected_last == result_last }

    result = ""
    called = false

    c = TestArraySite.new(url: url)
    c.wait = 0
    # Now, we don't call the alert Proc because we have no new things
    c.update()
    expected_error = "INFO -- TestArraySites::TestArraySite: Nothing new for #{url}"
    last_error = @logger_test_io.string.split("\n")[-1]
    assert { last_error.end_with?(expected_error) }
    expected_html = Site::HTML_HEADER.dup + [
      "<ul style=\"list-style-type: none;\">",
      "</ul>"
    ].join("\n")
    assert { !called }
    assert { result == "" }
  end
end
