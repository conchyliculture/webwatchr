require_relative "../lib/site"
require "digest"

class YanWen < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    key = "00#78a13&ba6c;73"
    md5 = Digest::MD5.hexdigest(track_id + key) # lol
    super(
      url: "https://track.yw56.com.cn/en/querydel?nums=#{track_id}&cyp=#{md5}",
      post_data: { 'timeZone' => 1 },
      every: every,
      comment: comment,
      )
  end

  def get_content()
    res = []
    date = ""
    @parsed_content.css('div.czhaodl dd,div.czhaodl dt').each do |jj|
      case jj.name
      when "dt"
        date = jj.text
      when "dd"
        time = jj.css("p.timePoint")[0].text
        desc = jj.css("div.cz_r h6")[0].text
        res << "<li>#{date} #{time}: #{desc}</li>"
      end
    end
    res.sort!.uniq!
    if res.empty?
      res = ["<ul>"] << res << ["</ul>"]
      return res.join("\n")
    end
    return ResultObject.new(nil)
  end
end

# Example:
#
# YanWen.new(
#     track_id: "UJ000000000YP",
#     )
