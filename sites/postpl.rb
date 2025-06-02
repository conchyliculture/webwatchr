require_relative "../lib/site"
require "mechanize"
require "json"

class PostPL < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://emonitoring.poczta-polska.pl/?lang=EN&numer=#{track_id}",
      every: every,
      comment: comment,
    )
    @json = nil
  end

  def pull_things
    mechanize = Mechanize.new
    ajax_headers = {
      "Content-Type" => "application/json; charset=utf-8",
      "API_KEY" => "BiGwVG2XHvXY+kPwJVPA8gnKchOFsyy39Thkyb1wAiWcKLQ1ICyLiCrxj1+vVGC+kQk3k0b74qkmt5/qVIzo7lTfXhfgJ72Iyzz05wH2XZI6AgXVDciX7G2jLCdoOEM6XegPsMJChiouWS2RZuf3eOXpK5RPl8Sy4pWj+b07MLg=.Mjg0Q0NFNzM0RTBERTIwOTNFOUYxNkYxMUY1NDZGMTA0NDMwQUIyRjg4REUxMjk5NDAyMkQ0N0VCNDgwNTc1NA==.b24415d1b30a456cb8ba187b34cb6a86"
    }
    params = {
      "addPostOfficeInfo": true,
      "language": "EN",
      "number": "RR472204914PL"
    }
    url = "https://uss.poczta-polska.pl/uss/v1.0/tracking/checkmailex"
    response = mechanize.post(url, params.to_json(), ajax_headers)
    @json = JSON.parse(response.body)
  end

  def get_content
    res = []
    @json["mailInfo"]["events"].each do |e|
      res << "#{e['time']} #{e['name']}"
    end
    return ResultObject.new(res.join("\n"))
  end
end

# Example:
#
# PostPL.new(
#     track_id: "RR192837465PL",
#     )
