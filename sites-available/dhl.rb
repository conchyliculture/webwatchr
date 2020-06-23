#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

require "json"

class DHL < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "https://www.dhl.com/shipmentTracking?AWB=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
    end
    def get_content()
        res = ""
#        begin
            j = JSON.parse(@html_content)
            status = j.dig("results",0, "delivery", "status")
            res << "Status: " + status + "<br>\n"
            res << "<ul>\n"
            j.dig("results", 0, "checkpoints"). each do |update|
              res << "<li>#{update['date']} #{update['time']}: #{update['description']}</li>\n"
            end
            res << "</ul>\n"
#        rescue
#            raise Site::ParseError.new "Please verify the DHL tracking ID"
#        end

        return res

    end
end

class DHLPrivate < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "https://www.dhl.de/int-verfolgen/search?language=en&lang=en&domain=de&lang=en&domain=de&piececode=#{track_id}",
            every: every,
            test: test,
            useragent: 'Mozilla/5.0 (X11; Linux x86_64; rv:77.0) Gecko/20100101 Firefox/77.0',
            comment: comment,
            http_ver: 2
        )
    end

    def get_content
      json_t = @parsed_content.css('script')[0].text[/JSON.parse\("(.+)"\),$/,1]
      j = JSON.parse(json_t.gsub("\\", ""))
      res = "<ul>"
      j["sendungen"][0]["sendungsdetails"]["sendungsverlauf"]["events"].each do |e|
        res << "<li>"+e["datum"]+": "+e["status"]+"</li>"
      end
      res += "</ul>"
      return res
    end
end

# example:
# DHLPrivate.new(
#    track_id: "123456789012",
#    every: 60*60,
#    test: __FILE__ == $0
#).update
