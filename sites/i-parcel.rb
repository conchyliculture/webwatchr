require_relative "../lib/site"

class IParcel < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://tracking.i-parcel.com/Home/Index?trackingnumber=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    @parsed_content.css("div.result").each { |row|
      date = row.css("div.date").text.split("\n").map(&:strip).join(" ")
      what = row.css("div.event").text.split("\n").map(&:strip).join(" ")
      res << "#{date} #{what}<br/>\n"
    }

    return res.join("")
  end
end

# Example:
#
# IParcel.new(
#     track_id: "AEIEDE00000000000",
#     )
