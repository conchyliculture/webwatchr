#!/usr/bin/ruby
# encoding: utf-8
require "fileutils"
require "logger"
require "pp"
require "test/unit"

$: << File.join(File.dirname(__FILE__),"..")
$: << File.join(File.dirname(__FILE__),"..","sites-available")

class TestClasse < Test::Unit::TestCase
    require "classe.rb"
    require "webrick"
    $wwwroot = File.join(File.dirname(__FILE__), 'www-root')
    $wwwport = 8001
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
        $content_is_string = "content_is_string.html"
        File.open(File.join($wwwroot, $content_is_string), "w") do |f|
            f.puts """<!DOCTYPE html>
            <meta charset=\"utf-8\">
            <title>test</title>
            👌 👌 👌 💯 💯 💯 💯 -KYop-R11Iqo.mp"""
        end
        $content_is_array = "content_is_array.html"
        File.open(File.join($wwwroot, $content_is_array), "w") do |f|
            f.puts """<!DOCTYPE html> <meta charset=\"utf-8\"> <title>test</title> <U+1F44C> <U+1F44C> <U+1F44C> <U+1F4AF> <U+1F4AF> <U+1F4AF> <U+1F4AF> -KYop-R11Iqo.mp <div> lol - lilo</div> <div> fi - fu</div>"""
        end

        restart_webrick()
        $CONF = JSON.parse(File.read(File.join(File.dirname(__FILE__),"..","config.json.template")))
    end

    def teardown()
        @serv_thread.exit
        $content_is_string = "content_is_string.html"
        File.open(File.join($wwwroot, $content_is_string), "w") do |f|
            f.puts ""
        end
    end

    def testContentIsString
        url = "http://localhost:#{$wwwport}/#{$content_is_string}"
        wait = 10*60

        result = ""

        $CONF["alert_proc"] = Proc.new{|x| result = x.to_s.encode('utf-8')}

        c = Classe.new( url: url,
                  every: wait,
                  test: true
                 )
        empty_last = {"content"=>nil, "time"=>-9999999999999}
        assert_equal(empty_last,c.read_last())
        assert_equal(true, c.should_check?(empty_last["time"]))
        assert_equal(false, c.should_check?((Time.now() - wait + 30).to_i))
        html = c.fetch_url(url)
        assert_equal(File.read(File.join($wwwroot,$content_is_string)), html)
        assert_equal("test", c.parse_noko(html).css('title').text)
        assert_equal(".lasts/last-2182cd5c8685baed48f692ed72d7a89f",c.last_file)
        c.update()
        assert_equal("{:content=>#{File.read(File.join($wwwroot,$content_is_string)).inspect}, :name=>\"#{url}\"}", result)

        File.open(File.join($wwwroot,$content_is_string),"a+") do |f|
            f.puts "new!"
        end
        c = Classe.new( url: url,
                  every: wait,
                  test: true
                 )
        c.update()
        assert_equal("{:content=>#{File.read(File.join($wwwroot,$content_is_string)).inspect}, :name=>\"http://localhost:#{$wwwport}/#{$content_is_string}\"}", result)
    end

    class TestArraySite < Classe
        def get_content()
            res=[]
            @parsed_content.css("div").each do |x|
                a,b = x.text.split('-')
                res << {'href' => a,"name"=>b}
            end
            return res
        end
    end

    def testContentIsArray
        url = "http://localhost:#{$wwwport}/#{$content_is_array}"
        wait = 10*60

        result = ""

        $CONF["alert_proc"] = Proc.new{|x| result = x.to_s.encode('utf-8')}

        c = TestArraySite.new( url: url,
                  every: wait,
                  test: true
                 )
        empty_last = {"content"=>nil, "time"=>-9999999999999}
        assert_equal(empty_last,c.read_last())
        assert_equal(true, c.should_check?(empty_last["time"]))
        assert_equal(false, c.should_check?((Time.now() - wait + 30).to_i))
        html = c.fetch_url(url)
        assert_equal("<!DOCTYPE html> <meta charset=\"utf-8\"> <title>test</title> <U+1F44C> <U+1F44C> <U+1F44C> <U+1F4AF> <U+1F4AF> <U+1F4AF> <U+1F4AF> -KYop-R11Iqo.mp <div> lol - lilo</div> <div> fi - fu</div>\n", html)
        assert_equal("test", c.parse_noko(html).css('title').text)
        assert_equal(".lasts/last-35e711989b197f20f3d4936e91a2c079",c.last_file)
        c.update()
        expected_result ="""<!DOCTYPE html>\n<meta charset=\"utf-8\">\n<ul style=\"list-style-type: none;\">\n<li><a href=' lol '> lilo </a></li>\n<li><a href=' fi '> fu </a></li>\n\n</ul>"""
		assert_equal("{:content=>#{expected_result.inspect}, :name=>\"#{url}\"}", result)

        File.open(File.join($wwwroot,$content_is_array),"a+") do |f|
            f.puts "<div>new! - new </div>"
        end
        c = TestArraySite.new( url: url,
                  every: wait,
                  test: true
                 )
        c.update()
        expected_result = expected_result.gsub("\n</ul>","<li><a href='new! '> new  </a></li>\n\n</ul>")
        assert_equal("{:content=>#{expected_result.inspect}, :name=>\"http://localhost:#{$wwwport}/#{$content_is_array}\"}", result)
    end
end
