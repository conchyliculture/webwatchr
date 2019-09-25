#!/usr/bin/ruby
# encoding: utf-8
require "fileutils"
require "logger"
require "pp"
require "test/unit"

class TestClasse < Test::Unit::TestCase
    require_relative "../lib/site.rb"
    require "webrick"

    $wwwroot = File.join(File.dirname(__FILE__), "www-root")
    $wwwport = 8001
    $content_is_string = "content_is_string.html"
    $content_is_array = "content_is_array.html"
    $CONF = JSON.parse(File.read(File.join(File.dirname(__FILE__),"..","config.json.template")))
    $CONF["last_dir"] = Dir.mktmpdir
    $logger_test_io = StringIO.new()
    $logger = Logger.new($logger_test_io)
    #$logger = Logger.new("/dev/null")

    class TestFileHandler < WEBrick::HTTPServlet::FileHandler
        def do_GET(req, res)
            res.status = 200
            res["Content-Encoding"] = "utf-8"
            res["Content-Type"] = "text/html; charset=utf-8"
            res.body = File.open(File.join($wwwroot,req.path)).read()
        end
    end

    def restart_webrick()
        @serv_thread.kill if @serv_thread
        @serv_thread = Thread.new do
            s = WEBrick::HTTPServer.new(:AccessLog => [],
                                        :Logger => WEBrick::Log::new("/dev/null", 7),
                                        :Port => 8001,
                                       )
            s.mount "/", TestFileHandler, $wwwroot
            s.start
        end
        sleep(1)
    end

    def setup
        FileUtils.mkdir_p($CONF["last_dir"])

        restart_webrick()
    end

    def teardown()
        @serv_thread.exit
        [$content_is_string, $content_is_array].each do |tf|
            File.open(File.join($wwwroot, tf), "w") do |f|
                f.puts ""
            end
        end
        FileUtils.remove_entry_secure($CONF["last_dir"])
    end

    class TestStringSite < Site::SimpleString
        def get_content()
            @parsed_content.css("div.content").text
        end
    end

    def testContentIsString

        content_html = "👌 👌 👌 💯 💯 💯 💯 -KYop-R11Iqo.mp"
        whole_html = Site::HTML_HEADER.dup
        whole_html += "<title>test</title><div class='content'>#{content_html}</div>"
        File.open(File.join($wwwroot, $content_is_string), "w") do |f|
            f.write whole_html
        end
        url = "http://localhost:#{$wwwport}/#{$content_is_string}"
        wait = 10*60

        result = {}

        $CONF["alert_procs"] = [Proc.new{|x| result = x}]

        c = TestStringSite.new(config:$CONF, url: url, comment:"comment")
        assert {c.load_state_file() == {}}
        empty_last = {"formatted_content"=>nil, "time"=>-9999999999999}
        assert {c.should_update?(empty_last["time"]) == true}
        assert {c.should_update?((Time.now() - wait + 30).to_i) == false}
        html = c.fetch_url(url)
        assert {whole_html == html}
        assert {c.parse_noko(html).css("title").text == "test"}
        assert {c.state_file().end_with?("last-2182cd5c8685baed48f692ed72d7a89f")}
        c.update()
        expected_error = "DEBUG -- : Alerting new stuff"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        first_pass_content = Site::HTML_HEADER + content_html
        assert {result[:content] == content_html}
        assert {result[:formatted_content] == first_pass_content}
        assert {result[:name] == url + " (comment)"}

        File.open(File.join($wwwroot,$content_is_string),"w+") do |f|
            f.write whole_html.gsub("</div>"," new ! </div>")
        end
        c = TestStringSite.new(config:$CONF, url: url, comment:"lol")
        c.update()
        expected_error = "INFO -- : Too soon to update #{url}"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        assert {result[:content] == content_html}
        assert {result[:formatted_content] == first_pass_content}
        assert {result[:name] == url + " (comment)"}

        c.wait = 0
        c.update()
        expected_error = "DEBUG -- : Alerting new stuff"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        assert {result[:content] == content_html+" new ! "}
        assert {result[:formatted_content] == first_pass_content+" new ! "}
        assert {result[:name] == url + " (lol)"}
        result_last = JSON.parse(File.read(c.state_file))
        result_last.delete("time")
        assert {result_last["url"] == url}
        assert {result_last["content"] == content_html+" new ! "}
        assert {result_last["wait"] == 0}
    end

    class TestArraySite < Site::Articles
        def get_content()
            res=[]
            @parsed_content.css("div").each do |x|
                a,b = x.text.split("-").map{|s| s.strip()}
                add_article({"id" => a, "url" => a, "title"=>b})
            end
            return res
        end
    end

    def testContentIsArray
        whole_html = Site::HTML_HEADER.dup
        whole_html += "<title>test</title>👌 👌 👌 💯 💯 💯 💯 -KYop-R11Iqo.mp"""
        whole_html += "<div> lol - lilo</div> <div> fi - fu</div>"
        File.open(File.join($wwwroot, $content_is_array), "w") do |f|
            f.write whole_html
        end
        url = "http://localhost:#{$wwwport}/#{$content_is_array}"
        wait = 10*60

        result = {}
        called = false
        $CONF["alert_procs"] = [Proc.new{|x| result = x; called = true}]

        c = TestArraySite.new(config: $CONF, url: url, every: wait)
        empty_last = {"formatted_content"=>nil, "time"=>-9999999999999}
        assert {c.load_state_file() == {}}
        assert {c.should_update?(empty_last["time"])}
        assert { ! c.should_update?((Time.now() - wait + 30).to_i)}
        html = c.fetch_url(url)
        assert {html == whole_html}
        assert {c.parse_noko(html).css("title").text == "test"}
        assert {c.state_file.end_with?("last-35e711989b197f20f3d4936e91a2c079")}

        # First full run, Get 2 things
        c.update()
        expected_error = "DEBUG -- : Alerting new stuff"
        last_error = $logger_test_io.string.split("\n")[-1].strip()
        assert {last_error.end_with?(expected_error)}
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style='list-style-type: none;'>",
            "<li id='lol'><a href='lol'>lilo</a></li>",
            "<li id='fi'><a href='fi'>fu</a></li>",
            "</ul>"].join("\n")
        result[:content].each{|x| x.delete('_timestamp')}
        assert {result[:content] == [
          {"id"=>"lol", "url"=>"lol", "title"=>"lilo"},
          {"id"=>"fi", "url"=>"fi", "title"=>"fu"}]}
        assert {result[:formatted_content] == expected_html}
        assert {result[:name] == url}
        assert {called}

        result = ""
        called = false

        File.open(File.join($wwwroot, $content_is_array),"a+") do |f|
            f.write "<div>new! - new </div>"
        end
        c = TestArraySite.new(config: $CONF, url: url)
        # Second run don't d anything because we shouldn't rerun
        c.update()
        expected_error = "INFO -- : Too soon to update #{url}"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        assert { ! called}
		assert {result == ""}

        result = ""
        called = false

        c.wait = 0
        # This time we set new things, and wait is 0 so we are good to go
        c.update()
        expected_error = "DEBUG -- : Alerting new stuff"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style='list-style-type: none;'>",
            "<li id='new!'><a href='new!'>new</a></li>",
            "</ul>"].join("\n")
        assert {called}

        result[:content].each{|x| x.delete('_timestamp')}
        assert {result[:content] == [{"id"=>"new!", "url"=>"new!", "title"=>"new"}]}
        assert {result[:formatted_content] == expected_html}
        assert {result[:name] == url}
        expected_last = {"url"=>"http://localhost:8001/content_is_array.html",
                         "wait"=>0,
                         "content"=>[{"id"=>"lol", "title"=>"lilo", "url"=>"lol"},
                                    {"id"=>"fi", "title"=>"fu", "url"=>"fi"},
                                    {"id"=>"new!", "title"=>"new", "url"=>"new!"}]}
        result_last = JSON.parse(File.read(c.state_file))
        result_last.delete("time")
        result_last["content"].each do |item|
            item.delete("_timestamp")
        end
        assert {expected_last == result_last}

        result = ""
        called = false

        c = TestArraySite.new(config: $CONF, url: url)
        # Now, we don't call the alert Proc because we have no new things
        c.update()
        expected_error = "INFO -- : Nothing new for #{url}"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style=\"list-style-type: none;\">",
            "</ul>"].join("\n")
        assert {!called}
		assert {result == ""}

        result = ""
        called = false

        # Test error
        @serv_thread.exit
        c = TestArraySite.new(config: $CONF, url: url)
        # Now, we don't call the alert Proc because we have no new things
        c.update()
        expected_error = "ERROR -- : Network error on #{url} : Failed to open TCP connection to localhost:8001 (Connection refused - connect(2) for \"localhost\" port 8001). Will retry in 0 + 30 minutes"
        last_error = $logger_test_io.string.split("\n")[-1]
        assert {last_error.end_with?(expected_error)}
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style=\"list-style-type: none;\">",
            "</ul>"].join("\n")
        assert {! called}
		assert {result == ""}
    end
end
