require_relative "../webwatchr/site"

class Wix < Site::SimpleString
  require "json"

  def get_content()
    res = ""
    jsons = @parsed_content.css('link').select { |l| l.attr('rel') == "preload" and l.attr('href') =~ /.json/ }.map { |l| l['href'] }
    jsons.each do |jurl|
      j = JSON.parse(Net::HTTP.get(URI.parse(jurl)))["data"]["document_data"]
      j.each do |_k, v|
        if v["type"] =~ /text/i
          r = Nokogiri::HTML.parse(v["text"])
          res += "#{r.text}\n"
        end
      end
    end
    return ResultObject.new(res)
  end
end

# Example:
#
#Wix.new(
#    url: "http://a.website/made.with/wix.com"
#    )
