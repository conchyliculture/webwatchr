#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

begin
  require "curb"
rescue LoadError => e
  puts "GLS.rb requires the curb gem, because of their shitty SSL version"
  raise e
end
require "json"


class GLS < Site::SimpleString

    attr_accessor :messages
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://gls-group.eu/app/service/open/rest/GROUP/en/rstt001?match=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
    end

    def pull_things()
      c = Curl::Easy.new(@url)
      c.set(:SSL_CIPHER_LIST, "DEFAULT:!DH") # Lol wtf srsly
      c.perform
      @parsed_content = JSON.parse(c.body_str)
    end

    def get_content()
      res = "<ul><li>"

      res << @parsed_content["tuStatus"][0]["history"].map{|x| "#{x['date']}: #{x['evtDscr']} (#{x['address'].values.map(&:strip).join(' ')})"}.join("</li></li>")

      res << "</li></ul>"
    end
end

# Example:
#
# GLS.new(
#     track_id: "12345678911",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
