require_relative "../webwatchr/site"
require "json"

class GLS < Site::SimpleString
  attr_accessor :messages

  def initialize(track_id:, postal_code:, every: 60 * 60, comment: nil)
    @state_file_name = "last-gls-#{track_id}-#{postal_code}"
    super(
      url: "https://gls-group.eu/app/service/open/rest/FR/en/rstt027?match=#{track_id}&postalCode=#{postal_code}&type=&caller=witt002&millis=#{Time.now.to_i}#{rand(1000)}",
      every: every,
      comment: comment,
   )
    @track_id = track_id
  end

  def get_content
    res = "<ul><li>"

    res << JSON.parse(@html_content)["tuStatus"][0]["history"].map do |x|
      "#{x['date']} #{x['time']}: #{x['evtDscr']} (#{x['address'].values.sort.map(&:strip).join(' ')})"
    end.join("</li><li>")

    res << "</li></ul>"
    return ResultObject.new(res)
  end
end

# Example:
#
# GLS.new(
#     track_id: "1234567890",
#     postal_code: 12345)
