require_relative "../lib/site"

class Pretalx < Site::SimpleString
  def initialize(every: 6 * 60 * 60)
    url = "https://docs.pretalx.org/changelog/#changelog"
    super(url: url, every: every, comment: "Pretalx security updates")
  end

  def get_content
    return ResultObject.new(@parsed_content.css("ul.simple li").map(&:text).select { |x| x =~ /(security|vulnerability|cve)/i }.join("\n"))
  end
end

# Pretalx.new()
