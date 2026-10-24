require_relative "../webwatchr/site"

# Sign up to https://developer.fedex.com
# Though you'll need a credit card :(

class FedexApi < Site::SimpleString
  require "stringio"
  require "zlib"

  def track_id(track_id)
    @track_id = track_id
    @url = "https://www.fedex.com/fedextrack/?trknbr=#{track_id}"
    return self
  end

  def client_id(client_id)
    @client_id = client_id
    return self
  end

  def client_secret(client_secret)
    @client_secret = client_secret
    return self
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
    raise StandardError, "Could not get bearer" if bearer.nil?

    json_data = _get_tracking_json(bearer, @track_id)
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
      "client_secret" => @client_secret
    }
    pp form_data
    req.set_form_data(form_data)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.set_debug_output $stderr if $VERBOSE
    http.start do |h|
      resp = h.request(req)
      pp resp.body
      return JSON.parse(resp.body)['access_token']
    end
  end
end
