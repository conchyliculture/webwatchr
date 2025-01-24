require_relative "../lib/site"

require "json"

class Planzer < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://parcelsearch.quickpac.ch/api/ParcelSearch/GetPublicTracking/#{track_id}/en/false",
      every: every,
      comment: comment,
    )
    @track_id = track_id
  end

  def pull_things
    data = {
      "sendung_nummer" => @track_id,
      "sendung_plz" => "",
      "log" => "false",
      "language" => "en"
    }
    res = Net::HTTP.post_form(URI.parse("https://planzer-paket.ch/wp-content/themes/yootheme/tracking_proxy.php"), data)
    deliver_number = JSON.parse(res.body)['redirect_to'].scan(/deliveryNumber=([0-9]+)/)[0][0]

    res = Net::HTTP.get(URI.parse("https://frontend.api.tracking.app.planzer.ch/Delivery/#{deliver_number}/Pak/positions"))
    package_id = JSON.parse(res)[0]["id"]

    res = Net::HTTP.get(URI.parse("https://frontend.api.tracking.app.planzer.ch/Delivery/#{deliver_number}/Pak/position/#{package_id}/events"))
    @parsed_content = JSON.parse(res)
  end

  def get_content()
    res = []
    unless @parsed_content
      raise Site::ParseError, "Nothing found for #{@track_id}. Check it is correct."
    end

    @parsed_content.each do |p|
      res << "#{p['eventDate']}: #{p['description']['english']}"
    end

    return res.join("\n\n")
  end
end

# Example:
#
# Planzer.new(
#    track_id: "91920481920180918890")
