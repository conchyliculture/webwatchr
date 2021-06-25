#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

require "curb"
require "json"

class DHL < Site::SimpleString

    def initialize(track_id:, api_key: nil, every:, comment:nil, test:false)
        unless api_key
          raise Exception.new('DHL requires an API key for fetching tracking information. Get one by registering for a free account at https://developer.dhl.com/')
        end
        @api_key = api_key
        @track_id = track_id
        super(
            url:  "https://www.dhl.com/ch-en/home/tracking/tracking-express.html?submit=1&tracking-id=#{track_id}",
            every: every,
            test: test,
            comment: comment
        )
    end

    def pull_things()
      c = Curl.get("https://api-eu.dhl.com//track/shipments?trackingNumber=#{@track_id}")
      c.headers["DHL-API-Key"] = @api_key
      c.perform
      @parsed_content = JSON.parse(c.body_str)
    end

    def get_content()
      shipment = @parsed_content["shipments"][0]
      res = []
      if @comment
        res << "Update for #{@comment}"
      end
      if shipment["estimatedTimeOfDeliveryRemark"]
        res << "Estimated time of delivery: #{shipment["estimatedTimeOfDeliveryRemark"]}"
      end

      res << "<ul>"
      @parsed_content["shipments"][0]["events"].each do |e|
        res << "<li>#{e["timestamp"]}: #{e["description"]} (#{e.dig('location', 'address', 'addressLocality')})</li>"
      end
      res << "</ul>"

      return res.join("\n")

    end
end

# example:
# DHL.new(
#     track_id: "1234567890",
#     api_key: "j6VSqAm4RmlljLKJLajlP",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
