require_relative "../lib/site"

class PostNL < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "http://www.postnl.post/details/",
      post_data: { "barcodes" => track_id },
      every: every,
      comment: comment,
    )
  end

  def get_content()
    res = []
    table = @parsed_content.css("tbody tr").map { |row| row.css("td").map { |r| r.text.strip } }
    if table.empty?
      raise Site::ParseError, "Please verify the PostNL tracking ID"
    end

    table.each do |r|
      res << "#{r[0]} : #{r[1]}<br/>\n"
    end
    return res.join("")
  end
end

# Example:
#
# PostNL.new(
#     track_id: "RSAAAAAAAAAAAAA",
#     )
