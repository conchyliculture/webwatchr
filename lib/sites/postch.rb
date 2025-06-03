require_relative "../webwatchr/site"
require "json"
require "mechanize"

class PostCH < Site::SimpleString
  def url
    "https://www.post.ch/api/TrackAndTrace/Get?sc_lang=en&id=#{@track_id}"
  end

  def initialize
    @events = []
    @mechanize = Mechanize.new()
    @mechanize.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0'
    @text_messages = {}
    super()
  end

  def code_to_message(code)
    @text_messages = JSON.parse(@mechanize.get("https://service.post.ch/ekp-web/core/rest/translations/en/shipment-text-messages").body)['shipment-text--'] if @text_messages == {}
    @text_messages.each do |k, v| # W: Unused block argument - `v`. If it's necessary, use `_` or `_v` as an argument …
      ccode = code.split('.')
      kk = k.split('.')
      0.upto(ccode.size()) do |i|
        c = ccode[i]
        e = kk[i]
        if c.nil? and i == kk.size - 1
          return v
        end
        next if e == "*"
        next if c == e

        break
      end
    end
    return code
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
    jresp = JSON.parse(resp.body)
    if jresp.empty?
      raise Site::ParseError, "No result for #{@track_id}. Check that it is valid."
    end

    identity = jresp[0]['identity']

    resp = @mechanize.get("https://service.post.ch/ekp-web/api/shipment/id/#{identity}/events", nil, nil, headers)

    json_content = JSON.parse(resp.body)
    @parsed_content = []

    json_content.each do |event|
      event['description'] = code_to_message(event['eventCode'])
      @parsed_content << event
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
    evs = @parsed_content.map { |e|
      e['timestamp'] = DateTime.strptime(e['timestamp'], "%Y-%m-%dT%H:%M:%S%Z")
      e
    }
    evs.sort { |a, b| a['timestamp'] == b['timestamp'] ? a['description'] <=> b['description'] : a['timestamp'] <=> b['timestamp'] }.reverse.each do |event|
      msg = "#{event['timestamp']}: #{event['description']}"
      if event['city'] and event['city'] != ""
        msg += " (#{event['city']} #{event['zip']})"
      end
      @events << msg
    end

    return ResultObject.new(@events.join("\n"))
  end
end

# Example:
#
#  update PostCH do
#    track_id "LS203038460CH"
#  end
