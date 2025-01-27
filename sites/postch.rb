require_relative "../lib/site"
require "json"
require "mechanize"

class PostCH < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.post.ch/api/TrackAndTrace/Get?sc_lang=en&id=#{track_id}",
      every: every,
      comment: comment,
    )
    @track_id = track_id
    @events = []
    @mechanize = Mechanize.new()
    @mechanize.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0'
  end

  def pull_things()
    # First we need an anonymous userId
    resp = @mechanize.get("https://service.post.ch/ekp-web/api/user", nil, nil, { 'accept' => 'application/json' })
    user_id = JSON.parse(resp.body)['userIdentifier']
    csrf_token = resp.header["x-csrf-token"]

    headers = {
      'accept' => 'application/json, text/plain, */*',
      'Accept-Encoding' => 'gzip,deflate,br,zstd',
      'accept-language' => 'en',
      'Cache-Control' => 'no-cache',
      'Content-Type' => 'application/json',
      'Origin' => 'https://service.post.ch',
      'Referer' => 'https://service.post.ch',
      'X-Csrf-Token' => csrf_token
    }

    resp = @mechanize.post("https://service.post.ch/ekp-web/api/history?userId=#{user_id}", { 'searchQuery' => @track_id }.to_json, headers)
    hash = JSON.parse(resp.body)['hash']

    resp = @mechanize.get("https://service.post.ch/ekp-web/api/history/not-included/#{hash}?userId=#{user_id}", nil, nil, headers)
    identity = JSON.parse(resp.body)[0]['identity']

    resp = @mechanize.get("https://service.post.ch/ekp-web/api/shipment/id/#{identity}/events", nil, nil, headers)

    @text_messages = JSON.parse(@mechanize.get("https://service.post.ch/ekp-web/core/rest/translations/en/shipment-text-messages").body)

    json_content = JSON.parse(resp.body)
    @parsed_content = []

    json_content.each do |event|
      @text_messages["shipment-text--"].each_key do |tm|
        ttmm = tm.split(".")
        ccode = event["eventCode"].split(".")
        next unless ccode[0] == ttmm[0] and ccode[3] == ttmm[3]

        event['description'] = @text_messages["shipment-text--"][tm]
        @parsed_content << event
        break
      end
    end
  end

  def get_html_content()
    res = []
    res << Site::HTML_HEADER
    res << "<ul>"
    @events.each do |e|
      res << "<li>#{e}</li>"
    end
    res << "</ul>"
    return res.join("\n")
  end

  def get_content()
    @parsed_content.sort_by { |e| DateTime.strptime(e['timestamp']) }.reverse.each do |event|
      msg = "#{event['timestamp']}: #{event['description']}"
      if event['city'] != ""
        msg += " (#{event['city']} #{event['zip']})"
      end
      @events << msg
    end

    return @events.join("\n")
  end
end

# Example:
#
# PostCH.new(
#     track_id: "99.10.100000.100000003",
# )
