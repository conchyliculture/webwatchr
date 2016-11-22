$: << File.dirname(__FILE__)

require "classe.rb"

$MAXDEALS=5
$BADCATEGORY=["mode"]

class Dealabs < Classe 

    def get_content()
        message_html=<<EOM
<html>
<body>
<ul>
EOM
        articles=[]
        Nokogiri.parse(@http_content).css("article").each do |article|
            categories = article.css('div.content_part').css('p.categorie').css('a').map{|x| x.text.downcase}

            title = article.css('a.title').text
            unless (categories & $BADCATEGORY ).empty?
                puts "Ignoring #{title} because #{(categories & $BADCATEGORY)}" if $VERBOSE
                next
            end
            link = article.css('a.title').attr('href').text
            img = article.css('div#over img').attr('src').text
            articles  << "<li><a href='#{link}'><img src='#{img}'> #{title}  / (#{categories.join('|')})  </a></li>"
            break if articles.size == $MAXDEALS
        end
        message_html+=articles.join("\n")
        message_html+= <<EOM
</ul>
</body>
</html>
EOM
        @msg= message_html
        return message_html
    end

end

q=Dealabs.new(url:  "https://www.dealabs.com/",
              every: 30*60, 
              test: __FILE__ == $0
             )
