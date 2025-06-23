require_relative "../webwatchr/site"

# example:
#
#  update PostNL do
#    track_id "XX102917683NL"
#  end

class PostNL < Site::SimpleString
  require "net/http"
  require "json"

  def track_id(track_id)
    # Sets the Track ID & URL
    @track_id = track_id
    @url = "https://www.postnl.post/track?barcodes=#{track_id}"
    self
  end

  def initialize
    super()
    @update_interval = 6 * 60 * 60
    @parsed_json = nil
  end

  def pull_things()
    resp = Net::HTTP.post(URI.parse("https://postnl.post/api/v1/auth/token"), nil, nil)
    token = JSON.parse(resp.body)["access_token"]

    resp = Net::HTTP.post(
      URI.parse("https://postnl.post/api/v1/tracking-items"), {
        "items" => ["CH188699083NL"],
        "language_code" => "en"
      }.to_json,
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }
    )
    if resp.body =~ /API calls quota exceeded!/
      raise Site::ParseError, resp.body
    end

    @parsed_json = JSON.parse(resp.body)
  end

  def extract_content()
    res = Site::SimpleString::ListResult.new()
    @parsed_json['data']['items'][0]['events'].each do |event|
      msg = "#{event['datetime_local']}: #{event['status_description']}"
      if event['country_code']
        msg << " (#{event['country_code']})"
      end
      res << msg
    end

    return res
  end
end
