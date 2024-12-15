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
    def initialize(track_id:, postal_code:, every:, comment:nil, test:false)
        super(
          url: "https://gls-group.eu/app/service/open/rest/FR/en/rstt027?match=#{track_id}&postalCode=#{postal_code}&type=&caller=witt002&millis=#{Time.now.to_i}#{rand(1000)}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
    end

    def get_content()
      res = "<ul><li>"

      res << JSON.parse(@html_content)["tuStatus"][0]["history"].map{|x| "#{x['date']} #{x['time']}: #{x['evtDscr']} (#{x['address'].values.sort.map(&:strip).join(' ')})"}.join("</li><li>")

      res << "</li></ul>"
    end
end

# Example:
#
# GLS.new(
#     track_id: "1234567890",
#     postal_code: 12345,
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
