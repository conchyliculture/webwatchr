require_relative "../lib/site"

require "json"

class Quickpac < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    case track_id
    when /^[0-9]{18}$/
      @track_id = track_id.scan(/^(..)(..)(......)(........)$/)[0].join(".")
    when /^[0-9]{2}\.[0-9]{2}\.[0-9]{6}\.[0-9]{8}$/
      @track_id = track_id
    else
      raise Site::ParseError, "track_id should either in fortmat 121212345612345678 or 12.12.123456.12345678"
    end

    super(
      url: "https://parcelsearch.quickpac.ch/api/ParcelSearch/GetPublicTracking/#{track_id}/en/false",
      every: every,
      comment: comment,
    )
  end

  def parse_content(html)
    @parsed_content = JSON.parse(html)
  end

  def get_content()
    res = []
    if not @parsed_content or not @parsed_content["Protocol"]
      raise Site::ParseError, "Nothing found for #{@track_id}. Check it is correct."
    end

    @parsed_content["Protocol"].each do |p|
      res << "#{p['Time']}: #{p['StatusText']}}"
    end

    return res.join("\n")
  end
end

# Example:
#
# Quickpac.new(
#    track_id: "11.00.101900.29374912",
# )
