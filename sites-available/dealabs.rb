#!/usr/bin/ruby
# encoding: utf-8
require "cgi"
require "json"

require_relative "../lib/site.rb"

# Here list the categories you're not interested in
$BADCATEGORY = Regexp.union(
    [
        /^mode$/,
        /^bons plans (e\. leclerc|carrefour|auchan|boulanger|fnac)$/,
        /^Épicerie$/,
        /itunes/,
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
            title = article.css('a.space--v-1').text
            if match_category(categories)
                @logger.debug "Ignoring #{title} because #{categories} have bad category"
                next
            end
            img_html = article.css('img.imgFrame-img')
            img = img_html.attr('src').text
            link_html = article.css('a.imgFrame')
            if img=~/^data:image\/gif;base64/
                img = JSON.parse(CGI.unescapeHTML(img_html.attr('data-lazy-img')))["src"]
            end
            link = link_html.attr('href').text
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
