require_relative "../webwatchr/site"

require "json"

class Cainiao < Site::SimpleString
  API_URL = "https://global.cainiao.com/global/detail.json".freeze

  def track_id(track_id)
    @track_id = track_id
    @url = "https://global.cainiao.com/newDetail.htm?mailNoList=#{track_id}&otherMailNoList="
    self
  end

  def initialize
    super()
    @update_interval = 6 * 60 * 60
    @parsed_json = nil
  end

  def pull_things()
    @extra_headers["Referer"] = @url
    body = fetch_url("#{API_URL}?mailNos=#{@track_id}&lang=en")
    @parsed_json = JSON.parse(body)
    raise Site::ParseError, "API returned failure" unless @parsed_json["success"]
  end

  def extract_content()
    package = @parsed_json["module"]&.first
    raise Site::ParseError, "No package data in response" unless package

    details = package["detailList"] || []

    res = Site::SimpleString::ListResult.new()

    if details.empty?
      status = package["statusDesc"] || package["status"] || "Unknown"
      eta_info = package["globalEtaInfo"]
      if eta_info && eta_info["deliveryMinTime"]
        min_date = Time.at(eta_info["deliveryMinTime"] / 1000).strftime("%Y-%m-%d")
        max_date = Time.at(eta_info["deliveryMaxTime"] / 1000).strftime("%Y-%m-%d")
        res << "#{status} (ETA: #{min_date} – #{max_date})"
      else
        res << status
      end
    else
      details.each do |event|
        time = event["timeStr"] || ""
        desc = event["desc"] || event["standerdDesc"] || ""
        location = event["area"] || event["city"] || ""
        msg = "#{time}: #{desc}"
        msg += " (#{location})" unless location.empty?
        res << msg
      end
    end

    return res
  end
end
