require_relative "../lib/site"

class FedexApi < Site::SimpleString
  require "stringio"
  require "zlib"

  def initialize(track_id:, client_id:, secret_key:, every: 60 * 60, comment: nil)
    @client_id = client_id
    @secret_key = secret_key
    @track_id = track_id
    super(
      url: "https://www.fedex.com/fedextrack/?trknbr=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def _get_tracking_json(bearer, track_id)
    uri = URI("https://apis.fedex.com/track/v1/trackingnumbers")
    #uri = URI("https://apis-sandbox.fedex.com/track/v1/trackingnumbers")
    req = Net::HTTP::Post.new(uri)
    form_data = {
      "includeDetailedScans" => true,
      "trackingInfo" => [{
        "trackingNumberInfo" => {
          "trackingNumber" => track_id
        }
      }]
    }
    req.set_form_data(form_data)
    req.set_content_type("application/json")
    req.body = form_data.to_json
    req['Authorization'] = "Bearer #{bearer}"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.set_debug_output $stderr if $VERBOSE
    http.start do |h|
      resp = h.request(req)
      f = File.new("/tmp/jj", "w")
      f.write(resp.body)
      f.close
      return JSON.parse(resp.body)
    end
  end

  def pull_things()
    res = ""
    bearer = _get_bearer()
    json_data =  _get_tracking_json(bearer, @track_id)
    json_data['output']['completeTrackResults'][0]['trackResults'][0]["scanEvents"].each do |event|
      status = event["eventDescription"] #=>"Picked up",
      l = event["scanLocation"] #=>"LONDONDERRY, NH",
      location = "#{l['city']}, #{l['stateOrProvinceCode']}, #{l['countryNamew']}"
      date = event["date"] #=>"2018-07-23",

      datetime = DateTime.strptime(date, "%Y-%m-%dT%H:%M:%S%z").to_s
      res += "- #{datetime} #{status} #{location}<br/>\n"
    end
    pp res
  end

  def _get_bearer()
    uri = URI("https://apis.fedex.com/oauth/token")
    #uri = URI("https://apis-sandbox.fedex.com/oauth/token")
    req = Net::HTTP::Post.new(uri)
    form_data = {
      "grant_type" => "client_credentials",
      "client_id" => @client_id,
      "client_secret" => @secret_key
    }
    req.set_form_data(form_data)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.set_debug_output $stderr if $VERBOSE
    http.start do |h|
      resp = h.request(req)
      return JSON.parse(resp.body)['access_token']
    end
  end
end

class Fedex < Site::SimpleString
  require "date"
  require "json"
  require "net/http"

  def initialize(track_id:, every: 60 * 60, comment: nil)
    raise Exception, "Fedex moved to Akamai, abandon hope this would work. Use FedexApi instead."
    super(
      url: "https://www.fedex.com/trackingCal/track",
      post_data: Fedex.make_post_data(track_id),
      every: every,
      comment: comment,
      )
  end

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

      datetime = DateTime.strptime(date + "T" + time + tz, "%Y-%m-%dT%H:%M:%S%z").to_s
      res += "- #{datetime} #{status} #{location}<br/>\n"
    end
    return res
  end

  def self.make_post_data(fedex_id)
    post_data = {
      "data" => { "TrackPackagesRequest" => { "appType" => "WTRK", "appDeviceType" => "DESKTOP", "supportHTML" => true, "supportCurrentLocation" => true, "uniqueKey" => "", "processingParameters" => {}, "trackingInfoList" => [{ "trackNumberInfo" => { "trackingNumber" => fedex_id, "trackingQualifier" => "", "trackingCarrier" => "" } }] } }.to_json,
      "action" => "trackpackages",
      "locale" => "en_US",
      "version" => 1,
      "format" => "json"
    }
    return post_data
  end
end

# Sign up to https://developer.fedex.com

# Example:
#
# Fedex.new(
#     track_id: "999999999",
# )
