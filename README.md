# WebWatchr

Silly script to periodically check webpages modifications.

No bullshit gem from hell.

# Installation

    apt-get install ruby ruby-nokogiri
    git clone https://github.com/conchyliculture/webwatchr/
    cd webwatchr
    cp config.json.template config.json

then edit config.json to your needs

Run the cron often

    */5 * * * * cd /home/poil/ruby-nokogiri; ruby webwatchr.rb > /dev/null

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
