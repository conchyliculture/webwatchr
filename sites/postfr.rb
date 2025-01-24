require_relative "../lib/site"

require "json"

class PostFR < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.laposte.fr/ssu/sun/back/suivi-unifie/#{track_id}?lang=en_GB",
      every: every,
      comment: comment,
    )
  end

  def get_content
    res = []
    j = JSON.parse(@html_content)
    j[0]['shipment']['event'].each do |e|
      res << "#{e['date']}: #{e['label']} (country: #{e['country']})"
    end
    return res.join("\n")
  end
end

# Example:
#
# PostFR.new(
#     track_id: "LD467901456FR",
#     )
