require_relative "../webwatchr/site"

class Colisprive < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.colisprive.com/moncolis/pages/detailColis.aspx?numColis=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    table = @parsed_content.css("table.tableHistoriqueColis tr").map { |row| row.css("td").map { |r| r.text.strip } }
    if table.size.empty?
      raise Site::ParseError, "Please verify the ColisPrivé tracking ID"
    end

    table.each do |r|
      next if "#{r[0]}#{r[1]}" == ""

      res << "#{r[0]} : #{r[1]}"
      if r[2].to_s != ""
        res << " (#{r[2]})"
      end
      res << "<br/>\n"
    end
    return ResultObject.new(res.join(""))
  end
end

# Example:
# Colisprive.new(track_id: "55600000000000000")
