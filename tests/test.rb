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
            s = WEBrick::HTTPServer.new(:Port => 8001, :DocumentRoot => File.join(File.dirname(__FILE__), 'www-root'))
            s.start
        end
        sleep(1)
    end

    def teardown()
        @serv_thread.exit
    end

    def testLol
        puts "yay"
        Classe.new( url:"http://localhost:8001/lol",
                  every: 10*60,
                  test: true
                 )
    end

end
