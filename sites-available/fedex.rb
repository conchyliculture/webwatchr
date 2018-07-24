#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Fedex < Site::SimpleString
    require "date"
    require "json"
    require "net/http"

    def get_content()
        package_info = JSON.parse(@html_content).dig("TrackPackagesResponse", "packageList")[0]
        estDeliveryDt = package_info["estDeliveryDt"]
        res = "Expected delivery: #{estDeliveryDt}<br/>\n"
        package_info.dig("scanEventList").each do |event|
            status = event["status"] #=>"Picked up",
            location = event["scanLocation"] #=>"LONDONDERRY, NH",
            date = event["date"] #=>"2018-07-23",
            time = event["time"] #=>"10:43:00",
            tz = event["gmtOffset"] #=>"-04:00",

            datetime = DateTime.strptime(date+"T"+time+tz, "%Y-%m-%dT%H:%M:%S%z").to_s
            res += "- #{datetime} #{status} #{location}<br/>\n"
        end
        return res
    end

    def Fedex.make_post_data(fedex_id)
        post_data = {
            "data" => {"TrackPackagesRequest"=>{"appType"=>"WTRK","appDeviceType"=>"DESKTOP","supportHTML"=>true,"supportCurrentLocation"=>true,"uniqueKey"=>"","processingParameters"=>{},"trackingInfoList"=>[{"trackNumberInfo"=>{"trackingNumber"=>fedex_id,"trackingQualifier"=>"","trackingCarrier"=>""}}]}}.to_json,
            "action"=>"trackpackages",
            "locale"=>"en_US",
            "version" =>1,
            "format"=>"json"
        }
        return post_data
    end
end

fedex_id = "999999999"

Fedex.new(
    url: "https://www.fedex.com/trackingCal/track",
    post_data: Fedex.make_post_data(fedex_id),
    every: 60*60,
    test: __FILE__ == $0
).update
