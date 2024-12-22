require_relative "../lib/site"

class Pretalx < Site::SimpleString
  def initialize(every:, test: false)
    url = "https://docs.pretalx.org/changelog/#changelog"
    super(url: url, every: every, comment: "Pretalx security updates", test: test)
  end

  def get_content
    @parsed_content.css("ul.simple li").map(&:text).select { |x| x =~ /(security|vulnerability|cve)/i }.join("\n")
  end
end

# Pretalx.new(
#   every: 24 * 3600,
#   test: __FILE__ == $PROGRAM_NAME
# ).update
