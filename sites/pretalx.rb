require_relative "../lib/site"

class Pretalx < Site::SimpleString
  def initialize(every:)
    url = "https://docs.pretalx.org/changelog/#changelog"
    super(url: url, every: every, comment: "Pretalx security updates", test: test)
  end

  def get_content
    @parsed_content.css("ul.simple li").map(&:text).select { |x| x =~ /(security|vulnerability|cve)/i }.join("\n")
  end
end

# Pretalx.new(
#   every: 24 * 3600,
# ).update
