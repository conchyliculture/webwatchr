require_relative "../webwatchr/site"
require "json"
require "mechanize"
require "openssl"
#require "logger"

class Yuntrack < Site::SimpleString
  def track_id(track_id)
    # Sets the Track ID & URL
    @track_id = track_id
    @url = "https://www.yuntrack.com/parcelTracking?id=#{track_id}"
    self
  end

  def initialize
    super()
    @mechanize = Mechanize.new()
    #    @mechanize.log = Logger.new(STDOUT)
    @mechanize.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0'
    @parsed_json = nil
  end

  def getsign()
    e = "Timestamp=#{Time.now.to_i}123&NumberList=[\"#{@track_id}\"]"
    hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), 'f3c42837e3b46431ddf5d7db7d67017d', e)
    return hmac
  end

  def pull_things()
    # First we need an cookie

    uri = URI.parse("https://services.yuntrack.com/Track/Query")
    req = Net::HTTP::Options.new(uri.request_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    #    http.set_debug_output(STDOUT)
    resp = http.request(req)
    cookie = resp['Set-Cookie'].split(';')[0].split('=')[1]

    @mechanize.cookie_jar.add("https://services.yuntrack.com/Track/Query", Mechanize::Cookie.new('acw_tc', cookie))

    data = "{\"NumberList\":[\"#{@track_id}\"],\"CaptchaVerification\":\"\",\"Year\":0,\"Timestamp\":#{Time.now.to_i}123,\"Signature\":\"#{getsign()}\"}"
    resp = @mechanize.post("https://services.yuntrack.com/Track/Query", data, { 'Content-Type' => 'application/json', 'Referer' => 'https://www.yuntrack.com/' })
    @parsed_json = JSON.parse(resp.body)
  end

  def extract_content()
    res = Site::SimpleString::ListResult.new()
    evs = @parsed_json['ResultList'][0]['TrackInfo']['TrackEventDetails'].map { |e|
      e
    }
    evs.each do |event|
      msg = "#{event['CreatedOn']}: #{event['ProcessContent']}"
      if event['ProcessLocation'] and event['ProcessLocation'] != ""
        msg += " (#{event['ProcessLocation']})"
      end
      res << msg
    end

    return res
  end
end

# Example:
#
#  update Yuntrack do
#    track_id "12712128719203038460"
#  end
