#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class USPS < Site::SimpleString

    def get_content()
        infos = @parsed_content.css('div#trackingHistory_1 div.row div.panel-actions-content')
        unless infos
            raise Site::ParseError.new("Please verify the USPS tracking ID #{@url}")
        end
        # Man this is crappy
        res = "Tracking History: <ul>"
        lignes = []
        ligne = []
        infos.children.each do |c|
            case c.text.strip
            when "Tracking History"
                next
            when ""
                next
            when /as of.*#{Time.now.year}/
                next
            when /#{Time.now.year}/
                lignes << ligne.join(' ') unless ligne == []
                ligne = [c.text.strip.gsub(/[\t\r\n]/, "")]
            else
                ligne << c.text.strip.gsub(/[\t\r\n]/, "")
            end
        end
        lignes << ligne.join(' ') unless ligne == []
        res << lignes.map{|x| "<li>#{x}</li>"}.join("\n")
        res << "</ul>"
        return res
    end

end

trackingnb = "LZ000000000US"
USPS.new(
    url: "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{trackingnb}",
    every: 60*60,
    test: __FILE__ == $0
).update

