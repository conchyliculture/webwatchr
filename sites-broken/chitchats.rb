require_relative "../webwatchr/site"

class ChitChats < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://chitchats.com/tracking/#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def get_content
    table = @parsed_content.css("div.tracking-history table")[0]
    res = ["<ul>"]
    table.css('tr').each do |tr|
      day = ""
      if tr.css('td.tracking-table__empty-heading').size == 2
        day = tr.css('td span')[0].text.strip
      end
      time = tr.css('td span')[0].text.strip
      thing = tr.css('td')[1].text.strip
      place = tr.css('td')[2].text.strip
      msg = "<li>#{day} #{time}: #{thing}"
      if place != ""
        msg << " (#{place})"
      end
      res << "#{msg}</li>"
    end
    res << "</ul>"
    return ResultObject.new(res.join("\n"))
  end
end

# Example:
#
# ChitChats.new(track_id: "10pokwhaos")
