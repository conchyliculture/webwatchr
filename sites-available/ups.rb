#!/usr/bin/ruby
# encoding: utf-8

require "json"
require "curb"
require_relative "../lib/site.rb"

class UPS < Site::SimpleString
    require "date"
    require "net/http"
    require "json"

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://www.ups.com/track?loc=null&tracknum=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
    end

    def pull_things()
        c = Curl.get(@url)
        c.perform
        _, *http_headers = c.header_str.split(/[\r\n]+/).map(&:strip)
        http_headers = http_headers.flat_map{|x| x.scan(/^(\S+): (.+)/)}
        http_headers = http_headers.inject({}){|acc, val| (acc[val[0]] ||= []) << val[1].split('; ')[0].split('=',2); acc}
        cookies = http_headers["Set-Cookie"].to_h

        c = Curl.post("https://www.ups.com/track/api/Track/GetStatus", '{"TrackingNumber":["'+@track_id.downcase() + '"]}')
        c.headers["X-XSRF-TOKEN"] = cookies["X-XSRF-TOKEN-ST"]
        c.headers["Content-Type"] = "application/json"
        c.headers["User-Agent"] = "curl/7.74.0" # stuff is necessary here
        c.headers["Cookie"] = cookies.slice("X-CSRF-TOKEN", "X-XSRF-TOKEN-ST").to_a.map {|x| x.join("=")}.join("; ")
        c.perform
        @json = JSON.parse(c.body_str)
    end

    def proper_time(date, time)
      at = DateTime.strptime(date+" "+time,  "%m/%d/%Y %l:%M %p")
      return at
    end

    def get_content()
      res = []
      sched_date = @json["trackDetails"][0]["scheduledDeliveryDate"]
      if sched_date
        sched_msg = "Scheduled delivery date: #{DateTime.strptime(sched_date, "%m/%d/%Y").strftime('%Y-%m-%d')}"
        case @json["trackDetails"][0]["scheduledDeliveryTime"]
        when "cms.stapp.eod"
          sched_msg << " by end of day"
        when "cms.stapp.9pm"
          sched_msg << " by 21h"
        when "cms.stapp.3pm"
          sched_msg << " by 15h"
        end

        res << sched_msg
      end

      res << "<ul>"
      @json["trackDetails"][0]["shipmentProgressActivities"].each do |e|
        next unless e["activityScan"]
        res << "<li>#{proper_time(e["date"], e["time"])}: #{e["activityScan"]} (#{e["location"]})</li>"
      end
      res << "</ul>"

      return res.join("\n")
    end
end

# Example:
#
# UPS.new(
#    track_id: "1Z0000000000000000",
#    every: 30*60,
#    test: __FILE__ == $0
#).update
