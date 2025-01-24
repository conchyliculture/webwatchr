require_relative "../lib/site"

require "json"

class Quickpac < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    track_id_re = /^[0-9]{2}\.[0-9]{2}\.[0-9]{6}\.[0-9]{8}$/
    unless track_id =~ track_id_re
      raise Site::ParseError, "track_id should match #{track_id_re}"
    end

    super(
      url: "https://parcelsearch.quickpac.ch/api/ParcelSearch/GetPublicTracking/#{track_id}/en/false",
      every: every,
      comment: comment,
    )
    @track_id = track_id
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
#    every: 30*60,
# ).update
