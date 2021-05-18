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

        @events = []
        @global_state = {}

        if not @messages
          build_messages()
        end
    end

    def build_messages()
        @messages = {}
        c = Curl.get("https://service.post.ch/ekp-web/core/rest/translations/en/shipment-text-messages.json")
        c.perform
        if not c.status == "200"
          @logger.warn "Couldn't pull messages.json"
          return
        end
        messages = JSON.parse(c.body_str)
        ["additional-services-text--", "shipment-text--"].each do |key|
          messages[key].each do |k,v|
            @messages[k] = v
          end
        end
    end

    def _code_key_check(key, pattern)
      key_a = key.split(".")
      pa = pattern.split(".")
      key_a.each_with_index do |element, i|
        if pa[i] == "*"
          next
        end
        if element != pa[i]
          return false
        end
      end
      return true
    end

    def _translate_code(key)
      key_a = key.split(".")
      @messages.each do |k, v|
        if _code_key_check(key, k)
          return v
        end
      end
      return nil
    end

    def pull_things()
        # First we need an anonymous userId
        c = Curl.get("https://service.post.ch/ekp-web/api/user")
        c.set(:HTTP_VERSION, Curl::HTTP_2_0)
        c.perform
        if not c.status == "200"
          raise Site::ParseError.new("Error getting https://service.post.ch/ekp-web/api/user : #{c.status}")
        end
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
        if @comment
          res << "Update for #{@comment}"
        end
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
            translated = _translate_code(event["eventCode"])
            res << "<li>[#{event['timestamp']}] #{translated} (#{(event["city"].to_s+ " "+event["country"].to_s).strip()})</li>"
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
