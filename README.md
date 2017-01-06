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
    # Take a breath here, it's going to be alright
    rvm implode
    gem uninstall --all
    sudo apt-get remove -y --purge rubygems-integration rubygems rake bundler
    sudo find / -name ".rvm" -exec rm -rf "{}" \;

Then edit config.json to your needs.

Then enable some sites for checking by linking from `sites-available` into `sites-enabled`

Run the cron often:

    */5 * * * * cd /home/poil/my_fav_scripts/webwatchr; ruby webwatchr.rb > /dev/null

# Supported websites

This means these website will only extract "interesting" information from the page, and won't use the whole html page.

* Bandcamp merch pages
* [Dealabs](https://www.dealabs.com)
* DHL tracking
* [galaxus/digitec daily deals](https://www.galaxus.com/LiveShopping/)
* [Noquarterprod](https://www.noquarterprod.com)
* postNL tracking
* [Qwertee](https://www.qwertee.com)
* UPS tracking

# Add a new site to watch

## Watch the whole HTML source of a page

Just make a file `sites-enabled/mysites.rb` and append new pages to the end as new instances

    #/usr/bin/ruby
    require_relative "classe.rb"
    c1 = Classe.new(
        url: "https://www.google.com",
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0  # This is so you can run ruby mysites.rb to check your code
    ).update
    c2 = Classe.new(
        url: "https://www.google.es",
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0  # This is so you can run ruby mysites.rb to check your code
    ).update

## Extract part of the DOM first

Basically, just make a new `sites/mysite.rb` using one of the two examples, below
then overwrite the `get_content()` method.

Also override the `content_to_html()` method if you want to change how the new content will be showed to you.

You can use `@parsed_content` which is a Nokogiri parsed HTML document.

### The interesting content is a String

In the following example, everytime the first `<table>` element appearing on the DOM
changes, this will use the HTML code of this element as the content to check for update.

    $: << File.dirname(__FILE__)
    require "classe.rb"

    class Mysite < Classe
        def get_content()
            # @parse_content is the result of Nokogiri.parse(html of https://www.mydomistoobig.pt)
            return @parsed_content.css("table.result-summary")[0].to_s
        end
    end

    s=Mysite.new(
        url: "https://www.mydomistoobig.pt",
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0
    ).update

### The interesting content is a list of Things

In the following example, you fetch an array of things at every run of the code. 
Only new elements (from the previous run) will be sent to you.

    $: << File.dirname(__FILE__)
    require "classe.rb"

    class Mysite < Classe
        def get_content()
            # Parses the DOM, returns an Array of Hash with articles
            #
            # <div class="article">
            #   <a href="http://lol/article/1.html">Lol 1</a>
            # </div>
            # <div class="article">
            #   <a href="http://lol/article/1.html">Lol 1</a>
            # </div>
            #
            # returns:
            # [{'id' => 1, 'url' => 'http://lol/article/1.html'},
            #   'id' => 2, 'url' => 'http://lol/article/2.html'}]
            #
            # If for example this previously only returned the following
            # [{'id' => 1, 'url' => 'http://lol/article/1.html'}]
            # A mail will be sent containing just HTML for the second article

            i = 0
            res = []
            @parsed_content.css("div.article") do |article|
                link = article.css("a").attr("href")
                i = i+1
                res << {"href" => url , "name" => i.to_s} # Magic keys for a nice html ul-li display
            end
            return res
        end

    s = Mysite.new(
        url: "https://www.mydomistoobig.pt",
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0
    ).update()

## Test your new thing

Just do `ruby sites-available/mysite.rb`. It will run, and display what it would alert you with, without updating the state.

If everything looks right, `cd sites-enabled; ln -s ../sites-available/mysite.rb .`

## I need to do more complex stuff!

If you need to do weird things like authentication, session handling, form posting and whatnots, and still don't want some useless bullshit bloated Gem, you can use [https://github.com/jjyg/libhttpclient/](https://github.com/jjyg/libhttpclient/)

## I need to do more even more complex stuff!

If you need javascript... well... lol.
