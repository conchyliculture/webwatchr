#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Songkick < Site::Articles

    def initialize(*)
        super
        unless @url.end_with?("/calendar")
            @logger.warn("Songkick should end with /calendar to get all concerts")
        end
    end

    def get_content()
        @parsed_content.css('ul.event-listings li').each do |event|
            next if event["class"] =~ /with-date/

            date = event.css("time")[0]["datetime"].gsub("T", " ")
            url = "https://www.songkick.com" + event.css('p a')[0]["href"]
            artist = event.css("p a span").text.strip
            location = event.css('p.location').text.gsub(/\s+/, " ")
            add_article({
                "id"=> url,
                "url"=> url,
                "title" => "#{date}: #{artist} at #{location}"
            })
        end
    end
end
    
# example
#Songkick.new(
#    url: "https://www.songkick.com/artists/7214659-carpenter-brut/calendar",
#    every: 12 * 60 * 60,
#    comment: "CarpenterBrut concerts",
#    test: __FILE__ == $0
#).update
