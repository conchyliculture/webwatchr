#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

begin
  require "curb"
rescue LoadError => e
  puts "HTTP/2 requires the curb gem"
  raise e
end
require "json"


class PostCH < Site::SimpleString

    attr_accessor :messages
    def initialize(track_id:, every:, messages:nil, comment:nil, test:false)
        super(
            url: "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
        @messages = messages

        if not @messages
          begin
            build_messages()
          rescue Exception
            puts "Error in pulling messages for postch"
          end
        end
    end

    def build_messages()
        c = Curl.get("https://service.post.ch/ekp-web/core/rest/translations/en/shipment-text-messages.json")
        c.perform
        messages = JSON.parse(c.body_str)
        shipment_text_old = messages["shipment-text--"]
        @messages = shipment_text_old.dup
        shipment_text_old.each do |k, v|
          if k=~/PARCEL\.\*\.\*\.([0-9]+)/
            @messages["PARCEL.*.#{$1}"] = v
          end
        end
    end

    def pull_things()
        # First we need an anonymous userId
        c = Curl.get("https://service.post.ch/ekp-web/api/user")
        c.set(:HTTP_VERSION, Curl::HTTP_2_0)
        c.perform
        user_id = JSON.parse(c.body_str)["userIdentifier"][13..-1]
        _, *http_headers = c.header_str.split(/[\r\n]+/).map(&:strip)
        http_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]
        cookie = http_headers["set-cookie"][/^([^;]+);/,1]

        # Then a hash for the shipment
        c = Curl.post("https://service.post.ch/ekp-web/api/history?userId=%3C%5Banonymous%5D%3E#{user_id}", {"searchQuery" => @track_id}.to_json)
        c.set(:HTTP_VERSION, Curl::HTTP_2_0)
        c.headers["content-type"] = "application/json"
        c.headers["x-csrf-token"] = http_headers["x-csrf-token"]
        c.headers["Cookie"] = cookie
        c.perform
        hash = JSON.parse(c.body_str)["hash"]

        # Then a corresponding identity
        c = Curl.get("https://service.post.ch/ekp-web/api/history/not-included/#{hash}?userId=%3C%5Banonymous%5D%3E#{user_id}")
        c.set(:HTTP_VERSION, Curl::HTTP_2_0)
        c.perform
        if c.body_str == "[]"
            raise Site::ParseError.new "Please verify the PostCH tracking ID"
        end

        @global_state = JSON.parse(c.body_str)[0]
        identity = @global_state["identity"]

        # And now the list of events
        c = Curl.get("https://service.post.ch/ekp-web/api/shipment/id/#{identity}/events/")
        c.set(:HTTP_VERSION, Curl::HTTP_2_0)
        c.perform
        @events = JSON.parse(c.body_str)
    end

    def get_content()
        res = []
        if @global_state["deliveryRange"]
          res << "Expected delivery time: between #{@global_state["deliveryRange"]["start"]} and #{@global_state["deliveryRange"]["end"]}"
        end
        if @global_state["calculatedDeliveryDate"]
          res << "Expected delivery day: #{@global_state["calculatedDeliveryDate"]}"
        end
        res << "<ul>"
        @events.sort{|x, y| y["timestamp"] <=> x["timestamp"]}.each do |event|
          if event["eventCode"]=~/PARCEL\.\*\..\.([0-9]+)$/
            event["eventCode"] = "PARCEL\.\*\.#{$1}"
          end
          if @messages
            res << "<li>[#{event['timestamp']}] #{@messages[event["eventCode"]]} (#{(event["city"].to_s+ " "+event["country"].to_s).strip()})</li>"
          else
            res << "<li>[#{event['timestamp']}] #{event["eventCode"]} (#{(event["city"].to_s+ " "+event["country"].to_s).strip()})</li>"
          end
        end
        res << "</ul>"
        return res.join("\n")
    end
end

# Example:
#
# PostCH.new(
#     track_id: "99.60.00000.00000000",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
