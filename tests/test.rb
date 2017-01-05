#!/usr/bin/ruby
# encoding: utf-8
require "fileutils"
require "logger"
require "sequel"
require "test/unit"

$: << File.join(File.dirname(__FILE__),"..")
$: << File.join(File.dirname(__FILE__),"..","sites-available")

class TestClasse < Test::Unit::TestCase
    require "classe.rb"
    require "webrick"

    class ClasseTest < Classe
        def initialize()
        end
    end

    def setup
        @serv_thread = Thread.new do 
            s = WEBrick::HTTPServer.new(:AccessLog => [], :Logger => WEBrick::Log::new("/dev/null", 7), :Port => 8001, :DocumentRoot => File.join(File.dirname(__FILE__), 'www-root'))
            s.start
        end
        sleep(1)
        $CONF = JSON.parse(File.read(File.join(File.dirname(__FILE__),"..","config.json.template")))
    end

    def teardown()
        @serv_thread.exit
    end

    def testLol
        url = "http://localhost:8001/lol"
        wait = 10*60

        c = Classe.new( url: url,
                  every: wait,
                  test: true
                 )
        empty_last = {"content"=>nil, "time"=>-9999999999999}
        assert_equal(empty_last,c.read_last())
        assert_equal(true, c.should_check?(empty_last["time"]))
        assert_equal(false, c.should_check?((Time.now() - wait + 30).to_i))
        html = c.fetch_url(url)
        assert_equal("<html>\n<title>test</title>\nqsedf q*sdfkq sd\nfq\ns\nd fq\nsd \n\n\n", html)
        assert_equal("test", c.parse_noko(html).css('title').text)
        assert_equal(".lasts/last-746aa790a1c8bf7f910a87b432fa95d2",c.last_file)
    end
end
