$: << File.dirname(__FILE__)

require "classe.rb"

$MAXDEALS = 10
# Here put the categories you're not interested in
$BADCATEGORY = Regexp.union([/^mode$/,/^bons plans (e\. leclerc|carrefour|auchan|boulanger|fnac)$/])

class Dealabs < Classe 

    def match_category(cats)
        cats.each do |cat|
            return true if cat=~$BADCATEGORY
        end
        return false
    end

    def get_content()
        articles=[]
        Nokogiri.parse(@http_content).css("article").each do |article|
            next if article.attr('class')=~/ expired/
            categories = article.css('div.content_part').css('p.categorie').css('a').map{|x| x.text.downcase}

            title = article.css('a.title').text
            if match_category(categories)
                puts "Ignoring #{title} because #{(categories & $BADCATEGORY)}" if $VERBOSE
                next
            end
            link = article.css('a.title').attr('href')
            img = article.css('div#over img').attr('src').text
            articles  <<{"href"=> link ,"name"=> "#{title}  / (#{categories.join('|')})", "img_src"=>img }
            break if articles.size == $MAXDEALS
        end
        return articles
    end
end

Dealabs.new(url:  "https://www.dealabs.com/",
              every: 30*60, 
              test: __FILE__ == $0
             )
