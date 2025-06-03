require_relative "../webwatchr/site"

class PostCN < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    table = @parsed_content.css("table.events_view tr").map { |row| row.css("td").map { |r| r.text.strip } }.delete_if(&:empty?)
    if table.empty?
      raise Site::ParseError, "Please verify the PostCH tracking ID"
    end

    table.each do |r|
      res << "#{r[0]} - #{r[1]} : #{r[3]}: #{r[2].split("\n")[-1].strip()}<br/>\n"
    end
    return ResultObject.new(res.join(""))
  end
end

# Example:
#
# PostCN.new(
#     track_id: "RP000000000CN",
#     )
