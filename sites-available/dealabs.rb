#!/usr/bin/ruby
# encoding: utf-8
require "cgi"
require "json"

require_relative "../lib/site.rb"

# Here list the categories you're not interested in
$BADCATEGORY = Regexp.union(
    [
        /^mode$/,
        /^(e\. leclerc|carrefour|auchan|boulanger|fnac)$/,
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
        Nokogiri.parse(@html_content).css("article").each do |article|
            next if article.attr('class')=~/expired/

            img_html = article.css('a.imgFrame')
            header_div = article.css('div.threadGrid-title')
            link = ""
            unless img_html.empty?
                link = img_html.attr('href').text
            end
            title = ""
            img = ""
            if not header_div.empty?
                title = header_div.css('a.thread-link').text.strip
                categories = article.css('span.cept-merchant-name').map{|x| x.text.downcase}
                img_ = article.css('img.imgFrame-img')
                img = img_.attr('src').text
                if img=~/^data:image\/gif;base64/
                    img = JSON.parse(CGI.unescapeHTML(img_.attr('data-lazy-img')))["src"]
                end
                if match_category(categories)
                    @logger.debug "Ignoring #{title} because #{categories} have bad category"
                    next
                end
                add_article({
                    "id" => link,
                    "url" => link,
                    "title" => "#{title}  / (#{categories.join('|')})",
                    "img_src" => img
                })
            end
        end
    end
end

Dealabs.new(
    url:  "https://www.dealabs.com/",
    every: 30*60,
    test: __FILE__ == $0
).update
