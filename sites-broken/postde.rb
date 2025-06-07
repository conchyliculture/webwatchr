require_relative "../webwatchr/site"

class PostDE < Site::SimpleString
  def initialize(track_id:, post_day:, post_month:, post_year:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.deutschepost.de/sendung/simpleQueryResult.html",
      post_data: {
        "form.sendungsnummer" => track_id,
        "form.einlieferungsdatum_monat" => post_month,
        "form.einlieferungsdatum_tag" => post_day,
        "form.einlieferungsdatum_jahr" => post_year
      },
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    table = @parsed_content.css("div.dp-table table tr").map { |row| row.css("td").map { |r| r.text.strip } }.delete_if(&:empty?)
    if table.empty?
      raise Site::ParseError, "Please verify the PostDE tracking ID"
    end

    table.each do |r|
      res << r[1].to_s
    end
    return ResultObject.new(res.join(""))
  end
end

# Example:
#
# PostDE.new(
#     track_id: "Rblol",
#     post_day: 16,
#     post_month: 2 ,
#     post_year: 2017,
#)
