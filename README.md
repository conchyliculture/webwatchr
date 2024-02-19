# WebWatchr

Silly script to periodically check webpage changes.

No bullshit gem from hell.

1. Script is run
2. checks for every new URL to check, if we've waited long enough
3. pulls interesting HTML from that page
4. if content is different, alerts you with the new content

# Installation

```shell
apt-get install ruby ruby-nokogiri 

# if you want fancier Diffs, for DiffString objects, apt install ruby-diffy
# I can't decide which web lib is the least bad
apt install ruby-curb ruby-mechanize

git clone https://github.com/conchyliculture/webwatchr/
cd webwatchr
cp config.json.template config.json

# Take a breath here, it's going to be alright
rvm implode
gem uninstall --all
sudo apt-get remove -y --purge rubygems-integration rubygems rake bundler
sudo find / -name ".rvm" -exec rm -rf "{}" \;
```

Then edit config.json to your needs, and enable some sites for checking by symlinking from `sites-available` into `sites-enabled`

Run the cron often:

    */5 * * * * cd /home/poil/my_fav_scripts/webwatchr; ruby webwatchr.rb

# Supported websites

This means these website will only extract "interesting" information from the page, and won't use the whole html page.

* Bandcamp merch pages
* [Dealabs](https://www.dealabs.com)
* Package tracking (DHL, Colissimo, i-parcel, Royalmail, PostNL, UPS, USPS)
* [galaxus/digitec daily deals](https://www.galaxus.com/LiveShopping/)
* [Noquarterprod](https://www.noquarterprod.com)
* [Qwertee](https://www.qwertee.com)
* [Trello](https://www.trello.com)
* [Twitter](https://www.twitter.com) (via [Nitter](https://github.com/zedeus/nitter) instances)

Some of these have been such a pain in the ass to scrape, I resorted to use their (usually terrible) APIs (ie: USPS)

# Add a new site to watch

## Watch the whole HTML source of a page

Just make a file `sites-enabled/mysites.rb` and append new pages to the end as new instances of the Site::SimpleString class.
By default it will check each page every hour.

```ruby
#/usr/bin/ruby
require_relative "../lib/site.rb"

Site::SimpleString.new(
    url: "https://www.google.com",
    test: __FILE__ == $0  # This is so you can run ruby mysites.rb to check your code
).update

Site::SimpleString.new(
    url: "https://www.google.es",
    test: __FILE__ == $0  # This is so you can run ruby mysites.rb to check your code
).update
```

## Extract part of the DOM first

Basically, just make a new `sites-enabled/mysite.rb` using one of the two examples below
then overwrite the `get_content()` method.

Use `@parsed_content` which is a Nokogiri parsed HTML document. Checkout `sites-available/dhl.rb` which is a simple example.

Also override the `to_html()` method if you want to change how the new content will be formatted.


### The interesting content is a String

In the following example, everytime the first `<table>` element appearing on the DOM
changes, this will use the HTML code of this element as the content to check for update.

```ruby
#/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

# We subclass Site::SimpleString, as the result of get_content() will be a String
class Mysite < Site::SimpleString
    def get_content()
        # @parse_content is the result of Nokogiri.parse(html of https://www.mydomistoobig.pt)
        return @parsed_content.css("table.result-summary")[0].to_s
    end
end

Mysite.new(
    url: "https://www.mydomistoobig.pt",
    every: 10*60 # Check every 10 minutes,
    test: __FILE__ == $0
).update
```

Move that into `sites-enabled`, and you're good to go.


### The page is a list of things and you want to know when a new thing is posted

In the following example, you fetch an array of things, that I call "articles" at every run of the code.
Only new articles that have never been seen will be sent.

```ruby
#!/usr/bin/ruby
# encoding: utf-8

require "../lib/site.rb"

class Mysite < Site::Articles 
        # This time, get_content calls add_article() on a Hash of "articles"
    def get_content()
        # Parses the DOM, returns an Array of Hash with articles
        #
        # If DOM is:
        # <div class="article">
        #   <a href="http://lol/article/1.html">Lol 1</a>
        # </div>
        # <div class="article">
        #   <a href="http://lol/article/1.html">Lol 1</a>
        # </div>
        #
        # returns:
        # [{'id' => 'http://lol/article/1.html', 'url' => 'http://lol/article/1.html'},
        #   'id' => 'http://lol/article/1.html', 'url' => 'http://lol/article/2.html'}]
        #
        # If for example this previously only returned the following
        # [{'id' => 'http://lol/article/1.html', 'url' => 'http://lol/article/1.html'}]
        # A mail will be sent containing just HTML for the second article

        res = []
        @parsed_content.css("div.article") do |article|
            link = article.css("a").attr("href")
            title = article.css("a").content

            add_article({
                "id"=> link, # This needs to be unique, per Article
                # Magic keys for a nice html ul/li message
                "url" => link,
                "title" => title
            })
        end
        # This time we don't return anything
    end

Mysite.new(
    url: "https://www.mydomistoobig.pt",
    every: 10*60 # Check every 10 minutes,
    test: __FILE__ == $0
).update()
```

## Test your new site

Just do `ruby sites-available/mysite.rb`. It will run, and display what it would alert you with, without updating the state.

If everything looks right, `cd sites-enabled; ln -s ../sites-available/mysite.rb .`

## I need to do more complex stuff!

If you need to do weird things like authentication, session handling, form posting and whatnots, I've been playing around with [Mechanize](https://github.com/sparklemotion/mechanize) and [Curb](https://github.com/taf2/curb) which are kind of nice, and also have proper Debian packages.

## I need to do more even more complex stuff!

If you need javascript... well... lol. I'll probably have to use Selenium one day but the later the better.

## Force a site check, ignoring the 'wait' parameter

This can be useful to run a site update at a specific time/day with a crontab, instead of every specified amount of time. You can force update a website using the -s flag:
```bash
ruby webwatchr.rb -s lol.rb
```
Make sure `lol.rb` is in the `sites-available` directory

# FAQ

## POST?

If you need to actually fetch your URL using a POST HTTP request, add `post_data` as argument, when instanciating your new class:

```ruby
postnl_id="RSAAAAAAAAAAAAA"
PostNL.new(
    url:  "http://www.postnl.post/details/",
    post_data: {"barcodes" => postnl_id},
    every: 30*60,
    test: __FILE__ == $0
).update
```

## Tests?

run `ruby tests/test.rb`

## Logs ?

You can use the @logger Logger object in your mysite.rb.

Set the log file in config.json under the "log" key

## Alerting

Email is the main method of alerting, but you can also set webwatchr to talk to you on Telegram through a bot.

First make a bot and grab a token following the [Telegram procedure](https://core.telegram.org/bots#6-botfather).

You also need to know the `chat_id` for its discussion with you. The code in [there](https://github.com/atipugin/telegram-bot-ruby/blob/master/examples/bot.rb) can help you.

Install some dependencies from the one and only repo you should kind of trust:

```
apt install ruby-virtus ruby-inflecto ruby-faraday
```

Then grab the code for the Telegram bot client. Run this from inside the current dir:

```
CURDIR="$(pwd)"
cd /tmp
git clone https://github.com/atipugin/telegram-bot-ruby
mv telegram-bot-ruby/lib/telegram "webwatchr/lib/"
cd -
```

Then edit the config.json file accordingly.
