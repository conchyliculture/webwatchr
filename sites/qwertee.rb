$: << File.dirname(__FILE__)

require "classe.rb"

class Qwertee < Classe 

    def get_content()
        shirts=[]
        @parsed_content.xpath("rss/channel/item").each do |entry|
            shirtName = entry.xpath("title").first.content
            shirtURL = entry.xpath("guid").first.content        
            entry_description = Nokogiri::HTML( entry.xpath("description").first.content )
            entry_description.remove_namespaces!
            shirtPhotoURL = entry_description.xpath("//img").first["src"]

            shirtPubDate = entry.xpath("pubDate").first.content
            shirts << { "shirt_name" => shirtName, "shirt_url" => shirtURL, "shirt_photo_url" => shirtPhotoURL }
        end
        return shirts
    end

    def content_to_html()
        message_html=<<EOM
<html>
<body>
<ul>
EOM
        @content.each do |item|
            message_html +="<li><a href='#{item["shirt_url"]}'><img src='#{item["shirt_photo_url"]}'> </a></li>\n"
        end
        message_html+= <<EOM
</ul>
</body>
</html>
EOM
        return message_html
    end

end

# I know I use the RSS page, I could use a RSS reader right?
# I could also use your mom.
Qwertee.new(url:  "https://www.qwertee.com/rss/",
              every: 12*60*60, 
              test: __FILE__ == $0
             )
