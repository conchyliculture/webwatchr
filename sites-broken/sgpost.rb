require_relative "../webwatchr/site"

class PostSG < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "http://www.singpost.com/track-items",
      post_data: {
        "track_number" => track_id,
        "captoken" => "",
        "op" => "Check item status"
      },
      every: every,
      comment: comment,
    )
  end

  # Here we want to do check only part of the DOM.
  #   @html_content contains the HTML page as String
  #   @parsed_content contains the result of Nokogiri.parse(@html_content)
  #
  def get_content()
    res = []
    l = @parsed_content.css("div.tracking-info-header div")
    if l.empty?
      raise Site::ParseError, "Please verify the PostSG tracking ID"
    end

    status = ""
    l.each do |ll|
      case ll.attr("class")
      when "tracking-status-text"
        status = ll.text.strip()
      when "tracking-no-text"
        date = ll.text.strip()
        if date =~ /\d\d\/\d\d\/\d\d\d\d/
          res << "#{date} : #{status}"
        end
      end
    end

    unless res.empty?
      return ResultObject.new(res.join("<br/>\n\n\n\n"))
    end

    return nil
  end
end

# Example:
#
# PostSG.new(
#     track_id: "RB000000000SG",
#     )
