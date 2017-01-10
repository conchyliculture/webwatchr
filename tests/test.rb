#!/usr/bin/ruby
# encoding: utf-8
require "fileutils"
require "logger"
require "pp"
require "test/unit"

class TestClasse < Test::Unit::TestCase
    require_relative "../lib/site.rb"
    require "webrick"

    $wwwroot = File.join(File.dirname(__FILE__), 'www-root')
    $wwwport = 8001
    $content_is_string = "content_is_string.html"
    $content_is_array = "content_is_array.html"
    $CONF = JSON.parse(File.read(File.join(File.dirname(__FILE__),"..","config.json.template")))
    $CONF["last_dir"] = Dir.mktmpdir

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

        result = ""

        $CONF["alert_proc"] = Proc.new{|x| result = x.to_s.encode('utf-8')}

        c = TestStringSite.new(url: url)
        empty_last = {"content"=>nil, "time"=>-9999999999999}
        assert_equal(empty_last,c.read_last())
        assert_equal(true, c.should_check?(empty_last["time"]))
        assert_equal(false, c.should_check?((Time.now() - wait + 30).to_i))
        html = c.fetch_url(url)
        assert_equal(whole_html, html)
        assert_equal("test", c.parse_noko(html).css('title').text)
        assert_block{c.last_file().end_with?("last-2182cd5c8685baed48f692ed72d7a89f")}
        c.update()
        first_pass_content = Site::HTML_HEADER + content_html
        assert_equal("{:content=>#{first_pass_content.inspect}, :name=>\"#{url}\"}", result)

        File.open(File.join($wwwroot,$content_is_string),"w+") do |f|
            f.write whole_html.gsub("</div>"," new ! </div>")
        end
        c = TestStringSite.new(url: url)
        c.update()
        assert_equal("{:content=>#{first_pass_content.inspect}, :name=>\"#{url}\"}", result)
        c.wait = 0
        c.update()
        assert_equal("{:content=>#{(first_pass_content+" new ! ").inspect}, :name=>\"#{url}\"}", result)
        expected_last = {"url"=>"http://localhost:8001/content_is_string.html", "wait"=>0, "content"=>content_html+" new ! "}
        result_last = JSON.parse(File.read(c.last_file))
        result_last.delete("time")
        assert_equal(expected_last, result_last)
    end

    class TestArraySite < Site::Articles
        def get_content()
            res=[]
            @parsed_content.css("div").each do |x|
                a,b = x.text.split('-').map{|s| s.strip()}
                add_article({'id' => a, "url" => a, "title"=>b})
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

        result = ""

        $CONF["alert_proc"] = Proc.new{|x| result = x.to_s.encode('utf-8')}

        c = TestArraySite.new(url: url)
        empty_last = {"content"=>nil, "time"=>-9999999999999}
        assert_equal(empty_last,c.read_last())
        assert_equal(true, c.should_check?(empty_last["time"]))
        assert_equal(false, c.should_check?((Time.now() - wait + 30).to_i))
        html = c.fetch_url(url)
        assert_equal(whole_html, html)
        assert_equal("test", c.parse_noko(html).css('title').text)
        assert_block{c.last_file().end_with?("last-35e711989b197f20f3d4936e91a2c079")}
        c.update()
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style=\"list-style-type: none;\">",
            "<li id='lol'><a href='lol'>lilo</a></li>",
            "<li id='fi'><a href='fi'>fu</a></li>",
            "</ul>"].join("\n")
		assert_equal("{:content=>#{expected_html.inspect}, :name=>\"#{url}\"}", result)

        File.open(File.join($wwwroot,$content_is_array),"a+") do |f|
            f.write "<div>new! - new </div>"
        end
        c = TestArraySite.new(url: url)
        c.update()
		assert_equal("{:content=>#{expected_html.inspect}, :name=>\"#{url}\"}", result)
        c.wait = 0
        c.update()
        expected_html = Site::HTML_HEADER.dup + [
            "<ul style=\"list-style-type: none;\">",
            "<li id='new!'><a href='new!'>new</a></li>",
            "</ul>"].join("\n")
        assert_equal("{:content=>#{expected_html.inspect}, :name=>\"http://localhost:#{$wwwport}/#{$content_is_array}\"}", result)
        expected_last = {"url"=>"http://localhost:8001/content_is_array.html",
                         "wait"=>0,
                         "content"=>[{"id"=>"lol", "title"=>"lilo", "url"=>"lol"},
                                    {"id"=>"fi", "title"=>"fu", "url"=>"fi"},
                                    {"id"=>"new!", "title"=>"new", "url"=>"new!"}]}
        result_last = JSON.parse(File.read(c.last_file))
        result_last.delete("time")
        assert_equal(expected_last, result_last)
    end
end
