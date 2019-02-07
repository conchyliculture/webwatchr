#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Qwertee < Site::Articles
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "https://www.qwertee.com/rss/",
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
        Nokogiri.parse(@html_content).xpath("rss/channel/item").each do |entry|
            shirtName = entry.xpath("title").first.content
            shirtURL = entry.xpath("guid").first.content
            entry_description = Nokogiri::HTML( entry.xpath("description").first.content )
            entry_description.remove_namespaces!
            shirtPhotoURL = entry_description.xpath("//img").first["src"]

            add_article({
                "title" => shirtName,
                "id" => shirtURL,
                "url" => shirtURL,
                "img_src" => shirtPhotoURL
            })
        end
    end
end

Qwertee.new(
    every: 6*60*60,
    test: __FILE__ == $0
).update
