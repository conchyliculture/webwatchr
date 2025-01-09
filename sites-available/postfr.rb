require_relative "../lib/site"

require "json"

class PostFR < Site::SimpleString
  def initialize(track_id:, every:, comment: nil, test: false)
    super(
      url: "https://www.laposte.fr/ssu/sun/back/suivi-unifie/#{track_id}?lang=en_GB",
      every: every,
      test: test,
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
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
