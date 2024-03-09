require "json"
require "mechanize"
require_relative "../lib/site.rb"

class UPS < Site::SimpleString
    require "date"
    require "net/http"
    require "json"

    def initialize(track_id:, every:, comment:nil, test:false)
      raise Exception.new("UPS Website switched to Akamai bot protection. They also offer no free/dev API tokens.")
        super(
          url: "https://www.ups.com/track?loc=null&tracknum=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
        @mechanize = Mechanize.new()
    end

    def pull_things()
        url = "https://www.ups.com/track"
        # Just get cookies
        @mechanize.get(url)
        data = {'Locale'=> 'en_US', 'TrackingNumber' => [@track_id]}
        headers = {'X-XSRF-TOKEN' => @mechanize.cookie_jar.cookies().select{|c| c.name == "X-XSRF-TOKEN-ST"}[0].value,
                    "Content-Type" => 'application/json',
                    "Cookie" => @mechanize.cookie_jar().map{|c| c.name+"="+c.value}.join('; ')}
        res = @mechanize.post("https://www.ups.com/track/api/Track/GetStatus?loc=en_US", data.to_json, headers)

        @json = JSON.parse(res.body)
        return @json
    end

    def proper_time(date, time)
      at = DateTime.strptime(date+" "+time,  "%m/%d/%Y %l:%M %p")
      return at
    end

    def get_content()
      res = []
      deets = @json["trackDetails"].select{|deets|deets['requestedTrackingNumber'] == @track_id}[0]
      sched_date = deets["scheduledDeliveryDate"]
      if sched_date and sched_date != ""
        sched_msg = "Scheduled delivery date: #{DateTime.strptime(sched_date, "%m/%d/%Y").strftime('%Y-%m-%d')}"
        case deets["scheduledDeliveryTime"]
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
      deets["shipmentProgressActivities"].each do |e|
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
