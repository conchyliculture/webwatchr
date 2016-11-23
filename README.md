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

Basically, just make a new `sites/mysite.rb` using one of the two examples,
then overwrite the `get_content()` method. Override the `content_to_html()`
method if you want to change how the content of the mail will be generated.

You can use `@parsed_content` which is a Nokogiri parsed HTML document.

### The interesting content is a String

In the following example, everytime the first `<table>` element appearing on the DOM
changes, this will send an email with the HTML code of this element.

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
    )

### The interesting content is a list of Things

In the following example, everytime the Array returned by `get_content()`
changes, this will send an email with code of this element.

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
                res << {"href" => url , "name" => i.to_s}
            end
            return res
        end

    s = Mysite.new(
        url: "https://www.mydomistoobig.pt",
        every: 10*60 # Check every 10 minutes,
        test: __FILE__ == $0
    )

## Test your new thing

Just do `ruby sites/mysite.rb`. It will run, and display what it would send by mail, without updating the state.

## I need to do more complex stuff!

If you need to do weird things like authentication, session handling, form posting and whatnots, and still don't want some useless bullshit bloated Gem, you can use [https://github.com/jjyg/libhttpclient/](https://github.com/jjyg/libhttpclient/)

## I need to do more even more complex stuff!

If you need javascript... well... lol.
