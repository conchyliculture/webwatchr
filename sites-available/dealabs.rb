#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

# Here list the categories you're not interested in
$BADCATEGORY = Regexp.union(
    [
        /^mode$/,
        /^bons plans (e\. leclerc|carrefour|auchan|boulanger|fnac)$/,
        /^Épicerie$/,
        /google play/
    ]
)

class Dealabs < Site::Articles 

    def match_category(categories)
        categories.each do |category|
            return true if category=~$BADCATEGORY
        end
        return false
    end

    def get_content()
        Nokogiri.parse(@http_content).css("article").each do |article|
            next if article.attr('class')=~/ expired/
            categories = article.css('div.content_part').css('p.categorie').css('a').map{|x| x.text.downcase}
            title = article.css('a.title').text
            if match_category(categories)
                @logger.debug "Ignoring #{title} because #{categories} have bad category"
                next
            end
            link = article.css('a.title').attr('href').text
            img = article.css('div#over img').attr('src').text
            add_article({
                "id" => link,
                "url" => link,
                "title" => "#{title}  / (#{categories.join('|')})",
                "img_src" => img
            })
        end
    end
end

Dealabs.new(
    url:  "https://www.dealabs.com/",
    every: 30*60,
    test: __FILE__ == $0
).update
