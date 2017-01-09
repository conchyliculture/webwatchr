#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Qwertee < Site::Articles

    def get_content()
        shirts=[]
        Nokogiri.parse(@http_content).xpath("rss/channel/item").each do |entry|
            shirtName = entry.xpath("title").first.content
            shirtURL = entry.xpath("guid").first.content
            entry_description = Nokogiri::HTML( entry.xpath("description").first.content )
            entry_description.remove_namespaces!
            shirtPhotoURL = entry_description.xpath("//img").first["src"]

            shirtPubDate = entry.xpath("pubDate").first.content
            shirts << { "name" => shirtName, "href" => shirtURL, "img_src" => shirtPhotoURL }
        end
        return shirts
    end
end

# I know I use the RSS page, I could use a RSS reader right?
# I could also use your mom.
Qwertee.new(url:  "https://www.qwertee.com/rss/",
              every: 12*60*60,
              test: __FILE__ == $0
           ).update
