#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "openssl"


# Ricard is broken and uses terrible SSL signature methods
# This means this script can't work with OpenSSL 1.1
# The workaround would be to patch the SSL Context for the
# http object to 1
# http://ruby-doc.org/stdlib-2.6/libdoc/openssl/rdoc/OpenSSL/SSL/SSLContext.html#method-i-security_level-3D
begin
    level = OpenSSL::SSL::SSLContext.new().security_level
    if level
        raise Exception.new("Sorry, your openssl library is too recent and won't work with Ricardo's crappy certificates")
    end
rescue NoMethodError
    # We fail, so we are using an old openssl versio, that will 
    # work with Ricardo
end


class Ricardo < Site::Articles 

    def get_content()
        @parsed_content.css('a.ric-article').each do |article|
            url = "https://www.ricardo.ch"+article['href']
            image = article.css('div.ric-article__image img')[0]['src']
            title = article.css('div.ric-article__name')[0].text

            add_article({
            "id" => url,
            "url" => url,
            "title" => title,
            "img_src" => image
            })
        end
    end
end

# Add some terms to search
# 
search_terms = ["ricardo"]
search_terms.each do |term|
    Ricardo.new(
        url:  URI.encode("https://www.ricardo.ch/fr/s/#{term}"),
        every: 30*60,
        test: __FILE__ == $0
    ).update
end
