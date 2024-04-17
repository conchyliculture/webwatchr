#!/usr/bin/ruby

require_relative "../lib/site.rb"

require "json"
require "logger"
require "net/http"

class PostSE < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "https://api2.postnord.com/rest/shipment/v1/trackingweb/shipmentInformation?shipmentId=#{track_id}&locale=en",
            every: every,
            test: test,
            comment: comment,
        )
        @events = []
    end

    def get_html_content()
      res = []
      res << Site::HTML_HEADER
      res << "<ul>"
      @events.each do|e|
        res << "<li>#{e}</li>"
      end
      res << "</ul>"
      return res.join("\n")
    end

    def pull_things
        headers = {'accept' => 'application/json, text/plain, */*',
                    "x-bap-key" => 'web-tracking-sc'}
        uri = URI.parse(@url)
        res = Net::HTTP.get(uri, headers)
        @parsed_content = JSON.parse(res)
    end

    def get_content
        @parsed_content['items'][0]["events"].each do |event|
          loc = event['location']
          location = loc['countryCode']
          if loc['name']
            location = "#{loc['name']}, #{location}"
          end
          @events << "#{event['eventTime']}: #{event['eventDescription']} (#{location})"
        end
        @content = @events.join("\n") 
        return @content
    end

end

# Example:
#
# PostSE.new(
#     track_id: "LY000000000SE",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
