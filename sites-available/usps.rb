#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class USPS < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @useragent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36"
        set_http_header("ISTL-INFINITE-LOOP", "1")
    end

    def clean(node)
      return node.text.delete("\r\n").gsub("\t", " ").gsub(/  +/, " ").strip()
    end

    def get_content()
        infos = @parsed_content.css('div.thPanalAction')
        unless infos
            raise Site::ParseError.new("Please verify the USPS tracking ID #{@url}")
        end
        res = "Tracking History: <ul>\n"
        infos[0].to_html().split("<hr>").each do |hr|
          ligne = Nokogiri::HTML.parse(hr).css('span').map {|span| clean(span)}.join(' ')
          res << "<li>#{ligne}</li>\n"
        end
        res << "</ul>"
        return res
    end

end

# Example:
#
# USPS.new(
#     track_id: "LZ000000000US",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
