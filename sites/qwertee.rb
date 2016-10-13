$: << File.dirname(__FILE__)

require "classe.rb"

class Qwertee < Classe 

    def get_content()
        message_html=<<EOM
<html>
<body>
<ul>
EOM
        shirts=[]
        Nokogiri.parse(@http_content).xpath("rss/channel/item").each do |entry|
            shirtName = entry.xpath("title").first.content
            shirtURL = entry.xpath("guid").first.content        
            entry_description = Nokogiri::HTML( entry.xpath("description").first.content )
            entry_description.remove_namespaces!
            shirtPhotoURL = entry_description.xpath("//img").first["src"]

            shirtPubDate = entry.xpath("pubDate").first.content
            shirts << { :shirtName => shirtName, :shirtURL => shirtURL, :shirtPhotoURL => shirtPhotoURL }
            message_html +="<li><a href='#{shirtURL}'><img src='#{shirtPhotoURL}'> </a></li>"
        end
        message_html+= <<EOM
</ul>
</body>
</html>
EOM
        @msg= message_html
        return message_html
    end

end

# I know I use the RSS page, I could use a RSS reader right?
# I could also use your mom.
q=Qwertee.new(url:  "https://www.qwertee.com/rss/",
              every: 12*60*60, 
              test: __FILE__ == $0
             )
