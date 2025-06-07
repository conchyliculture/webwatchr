require_relative "../webwatchr/site"

class RoyalMail < Site::SimpleString
  require "date"

  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://www.royalmail.com/track-your-item?trackNumber=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  # Here we want to do check only part of the DOM.
  #   @html_content contains the HTML page as String
  #   @parsed_content contains the result of Nokogiri.parse(@html_content)
  #
  def get_content()
    # Selects the content of the first table tag with the CSS class result-summary
    res = ""
    table = @parsed_content.css("table.sticky-enabled")
    if table.size.empty?
      raise Site::ParseError, "Please verify the RoyalMail tracking ID #{@url}"
    end

    table.css("tr")[1..].each do |tr|
      row = tr.css("td").map { |x| x.text.strip().gsub(/[\r\n\t]/, "").gsub(/  +/, " ") }
      begin
        time = DateTime.strptime("#{row[0]} #{row[1]}", "%d/%m/%y %H:%M")
        res << "#{time} : #{row[2]}<br/>\n"
      rescue StandardError
        res << row.join(" ")
      end
    end
    return ResultObject.new(res)
  end
end

# Example:
#
# RoyalMail.new(
#     track_id: "RN000000000GB",
#     )
