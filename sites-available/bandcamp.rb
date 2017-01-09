#!/usr/bin/ruby
# encoding: utf-8

require_relative "../sites-available/classe.rb"

class Bandcamp < Classe

    def get_content()
        res=[]
        if @merch
            if @http_content=~/You are being redirected, please follow <a href="([^"]+)"/
                return @http_content
            end
            @parsed_content.css('ol.merch-grid li').each do |xx|
                next unless xx.css('p.sold-out').empty?
                x = xx.css('a')
                url = x.attr('href').text
                img = x.css('img')
                img_url = img.attr('src').text
                if img_url =~ /\/img\/43.gif/
                    img_url = img.attr('data-original')
                end
                title = x.css('p.title').text.strip().gsub(/ *\n */,'')
                price = x.css('span.price').text
                res << {"href"=> url,
                        "img_src" => img_url,
                        "name" => "#{title} #{price}",
                }
            end
        else
            $stderr.puts "not implemented"
        end
        return res
    end

    def initialize(band,every,test,merch=false)
        @merch=merch
        super(url: "https://#{band}.bandcamp.com/#{'merch' if @merch}", every: every,test: test)
    end

end


# Insert your fav groups here
# ex: bandcamp = [
# "group1",
# "group2"
# ]
bandcamp=[
#
].each do |b|
    Bandcamp.new(b,12*60*60, __FILE__ == $0,true).update
end
