require_relative "../webwatchr/site"

require "json"

class Quickpac < Site::SimpleString
  def track_id(track_id)
    case track_id
    when /^[0-9]{18}$/
      @track_id = track_id.scan(/^(..)(..)(......)(........)$/)[-1].join(".")
    when /^[0-9]{2}\.[0-9]{2}\.[0-9]{6}\.[0-9]{8}$/
      @track_id = track_id
    else
      raise Site::ParseError, "track_id should either in fortmat 121212345612345680 or 12.12.123456.12345678"
    end
    @url = "https://parcelsearch.quickpac.ch/api/ParcelSearch/GetPublicTracking/#{track_id}/en/false"
  end

  def extract_content()
    @parsed_content = JSON.parse(@website_html)
    res = Site::SimpleString::ListResult.new()
    if not @parsed_content or not @parsed_content["Protocol"]
      raise Site::ParseError, "Nothing found for #{@track_id}. Check it is correct."
    end

    if @parsed_content["OutlookHeadline"]
      res << "#{@parsed_content['OutlookHeadline']} #{@parsed_content['OutlookInfo'].join(' ')}"
    end

    @parsed_content["Protocol"].each do |p|
      res << "#{p['Time']}: #{p['StatusText']}"
    end

    return res
  end
end
