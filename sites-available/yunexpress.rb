require "json"
require "mechanize"
require_relative "../lib/site.rb"

class YunExpress < Site::SimpleString
    require "date"
    require "net/http"
    require "json"

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://services.yuntrack.com/Track/Query&tracknum=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
        @mechanize = Mechanize.new()
    end

    def pull_things()
        url = "https://services.yuntrack.com/Track/Query"
        data = {
          "NumberList" => [@track_id],
          "CaptchaVerification" => "",
          "Year" => 0,
        }
        headers = {
          'Referer' => "https://www.yuntrack.com/",
          'Content-Type' => "application/json",
        }
        begin
          @mechanize.post(url, data.to_json, headers)
        rescue Mechanize::ResponseCodeError
          # Just get cookies
        end

        headers['Cookie'] = @mechanize.cookie_jar().select{|c| c.name == "acw_tc"}.map{|c| c.name+"="+c.value}.join('; ')
        res = @mechanize.post(url, data.to_json, headers)

        @json = JSON.parse(res.body)
        return @json
    end

    def get_content()
      res = []
      j = @json["ResultList"].select{|r| r["Id"]==@track_id}[0]
      res << "<ul>"
      res << "<li>YunExpress Tracking Number: #{j['TrackInfo']['WaybillNumber']}</li>"
      res << "<li>International Tracking Number: #{j['TrackInfo']['TrackingNumber']}</li>"
      j["TrackInfo"]["TrackEventDetails"].each  do |e|
        res << "<li>#{e["CreatedOn"]}: #{e["ProcessContent"]} (#{e["ProcessLocation"]})</li>"
      end

      return res.join("\n")
    end
end

# Example:
#
# YunExpress.new(
#    track_id: "YT0000000000000000",
#    every: 30*60,
#    test: __FILE__ == $0
#).update

