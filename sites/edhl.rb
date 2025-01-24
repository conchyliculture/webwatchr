require_relative "../lib/site"

class EDHL < Site::SimpleString
  require "date"
  require "json"

  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "http://webtrack.dhlglobalmail.com/?mobile=&trackingnumber=#{track_id}",
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    l = @parsed_content.css("ol.timeline li")
    if l.empty?
      raise Site::ParseError, "Please verify the eDHL tracking ID"
    end

    date = nil
    l.each do |ll|
      case ll.attr("class")
      when "timeline-date"
        date = ll.text
      when /timeline-event/
        time = ll.css("div.timeline-time").text.strip()
        descr = ll.css("div.timeline-description").text.strip()
        res << "#{date} #{time}: #{descr}"
      end
    end

    return res.join("<br/>\n")
  end
end

# Example:
#
# EDHL.new(
#     track_id: "000000")
#
