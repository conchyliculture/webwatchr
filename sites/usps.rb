#!/usr/bin/ruby
# encoding: utf-8

require "nokogiri"
require_relative "../lib/site.rb"

class USPS < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
      $stderr.puts "This is most likely broken :("

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
        return if res.size == 28 # empty
        return res
    end

end

class USPSAPI < Site::SimpleString
    def initialize(track_id:, username: nil, every:, comment:nil, test:false)
      unless username
        raise Exception.new('USPS requires you to register to their Web API at https://registration.shippingapis.com/ for fetching tracking information.')
      end
      @username = username
      @track_id = track_id
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.TrackRequest('USERID' => @username) {
          xml.TrackID('ID' => @track_id)
        }
      end

      super(
        url: "https://secure.shippingapis.com/ShippingAPI.dll?API=TrackV2&XML=#{builder.to_xml}",
        every: every,
        test: test,
        comment: comment
      )
    end

    def get_content()
      root = Nokogiri::XML.parse(@html_content)
      res = [root.css("TrackResponse TrackSummary")]
      res << "<ul>"
      root.css("TrackResponse TrackInfo TrackDetail").each do |deet|
        res << "<li>"+deet.text+"</li>"
      end
      res << "</ul>"
      return res.join("\n")
    end

end

# Example:
#
#USPSAPI.new(
#    username: "111OOOOO2222",
#    track_id: "UE000000000US",
#    every: 60*60,
#    test: __FILE__ == $0
#).update()
#
#
# This is most likely broken, use USPSAPI class above instead
# USPS.new(
#     track_id: "LZ000000000US",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
