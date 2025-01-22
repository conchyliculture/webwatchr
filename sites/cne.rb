require_relative "../lib/site"

class CNE < Site::SimpleString
  def initialize(track_id:, req_ts:, signature:, md5:, every:, comment: nil)
    super(
      url: "https://wapi.cne.com/tracking/officialWebsite?t=#{req_ts}",
      every: every,
      comment: comment,
    )
    @track_id = track_id
    @md5 = md5
    @signature = signature
  end

  def pull_things()
    # First we need an anonymous userId
    uri = URI(@url)
    req = Net::HTTP::Post.new(uri)
    post_data = {
      "logisticsNo": @track_id,
      "lan": "en",
      "md5": @md5
    }
    req.set_form_data(post_data)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri)
    req.content_type = "application/json"
    req.body = post_data.to_json
    req["signature"] = @signature
    req["User-Agent"] = "curl/7.88.1"
    res = http.request(req)
    @parsed_content = JSON.parse(res.body)
  end

  def get_content()
    res = []
    if @parsed_content["ReturnValue"] == 1
      @parsed_content["trackingEventList"].each do |event|
        msg = "#{event['date']}: #{event['details']}"
        if event['place']
          msg += " #{event['place']}"
        end
        res << msg
      end
    else
      return "No result from CNE API for #{@track_id}"
    end
    return res.join("\n")
  end
end

# Example:
#
# Curl POST would look like:
#
# curl 'https://wapi.cne.com/tracking/officialWebsite?t=<req_ts>' -X POST
#  -H 'Content-Type: application/json'
#  -H 'signature: <signature>'
#  --data-raw '{"logisticsNo":"<track_id>","lan":"en","md5":"<m5>"}'
#
# CNE.new(
#    track_id: "3A5V000000000",
#    req_ts: 1687770000000,
#    md5: "9eaaaaaaaaaaaaaaaaaaa",
#    signature: "9a198201820198201982",
#    every: 30*60,
#).update
