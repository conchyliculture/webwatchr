# WebWatchr

Silly script to periodically check webpage changes.

No bullshit gem from hell. Also very little tested XD

1. Script is run
2. checks for every new URL to check, if we've waited long enough
3. pulls whole HTML (or part of it) and Hashes it
4. if hash is different, sends an email with the whole HTML (or part of it) 

# Installation

    apt-get install ruby ruby-nokogiri
    git clone https://github.com/conchyliculture/webwatchr/
    cd webwatchr
    cp config.json.template config.json

then edit config.json to your needs

Run the cron often

    */5 * * * * cd /home/poil/my_fav_scripts/webwatchr; ruby webwatchr.rb > /dev/null

# Add a new site to watch

## Watch the whole HTML source of a page

Just edit sites/classe.rb and append new pages to the end as new instances

    c1 = Classe.new(
        url: "https://www.google.com", 
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0  # This is so you can run ruby classe.rb to check your code
    )
    c2 = Classe.new(
        url: "https://www.google.es", 
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0  # This is so you can run ruby classe.rb to check your code
    )
    
## Extract part of the DOM first

Copy `sites/classe.rb` as `sites/mysite.rb` then overwrite the `get_content()` method.
You can use `@parsed_content` which is a Nokogiri parsed HTML document.

    $: << File.dirname(__FILE__)
    require "classe.rb"

    class Mysite < Classe
        def get_content()
            return @parsed_content.css("table.result-summary")[0].to_s
        end
    end
    s=Mysite.new(
        url: "https://www.mydomistoobig.pt", 
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0 
    )
    
## Test your new thing

Just do `ruby mysite.rb`. It will run, and display what it would send by mail.
    
## I need to do more complex stuff!

If you need to do weird things like authentication, session handling, form posting and whatnots, and still don't want some useless bullshit bloated Gem, you can use https://github.com/jjyg/libhttpclient/

## I need to do more even more complex stuff!

If you need javascript... well... lol.


