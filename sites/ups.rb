require_relative "../lib/site"

require "json"
require "curb"
require "mechanize"

class UPS < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.ups.com/track?track=yes&trackNums=#{track_id}&loc=en_US&requester=ST/trackdetails",
      every: every,
      comment: comment,
    )
    @track_id = track_id
  end

  def pull_things()
    uri = URI(@url)
    req = Net::HTTP::Get.new(uri)
    user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0"
    req['User-Agent'] = user_agent

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    res = http.request(req)
    xsrf = res.get_fields('set-cookie').map { |x| x.split("=")[0..1] }.select { |k, _| k == "X-XSRF-TOKEN-ST" }[0][1].gsub('; domain', '')
    csrf = res.get_fields('set-cookie').map { |x| x.split("=")[0..1] }.select { |k, _| k == "X-CSRF-TOKEN" }[0][1].gsub('; domain', '')

    headers = {
      'Accept' => '*/*',
      'Accept-Encoding' => 'deflate, gzip, br, zstd',
      'User-Agent' => user_agent,
      'X-XSRF-TOKEN' => xsrf,
      'Content-Type' => "application/json",
      'DNT' => "1",
      "Connection" => "keep-alive",
      'Cookie' => "X-CSRF-TOKEN=#{csrf}",
      'Sec-Fetch-Site' => "same-site",
      "TE" => "trailers"
    }

    data = {
      "TrackingNumber" => [@track_id]
    }
    c = Curl::Easy.http_post("https://webapis.ups.com/track/api/Track/GetStatus?loc=en_US", data.to_json) do |curl|
      headers.each do |k, v|
        curl.set(:HTTP_VERSION, Curl::HTTP_2_0)
        curl.headers[k] = v
      end
    end
    c.perform
    gz = Zlib::GzipReader.new(StringIO.new(c.body_str))
    uncompressed_string = gz.read
    @parsed_content = JSON.parse(uncompressed_string)
  end

  def proper_time(date, time)
    at = DateTime.strptime("#{date} #{time}", "%m/%d/%Y %l:%M %p")
    return at
  end

  def get_content
    res = ['<ul>']
    @parsed_content['trackDetails'][0]['shipmentProgressActivities'].each do |e|
      res << "<li>#{proper_time(e['date'], e['time'])}: #{e['activityScan']} (#{e['location']})</li>"
    end
    res << "</ul>"
    return res.join("\n")
  end
end

# Exemple:
#
# UPS.new(
#   track_id: "89999019281729100",
#)
