# WebWatchr

Silly script to periodically check webpage changes.

No bullshit gem from hell.

1. run script every minute from cron
2. pulls data for every Website to check, if the last time we did that is long ago
4. if content is different, from the last time, alerts you with the new content (email, telegram)

# Installation

```shell
apt-get install ruby ruby-mechanize ruby-curb ruby-nokogiri 

# if you want fancier Diffs, for DiffString objects, apt install ruby-diffy

git clone https://github.com/conchyliculture/webwatchr/
cd webwatchr
cp config.json.template config.json

# Take a breath here, it's going to be alright
# I take no responsibility if you hate me after you ran that
rvm implode
gem uninstall --all
sudo apt-get remove -y --purge rubygems-integration rubygems rake bundler
sudo find / -name ".rvm" -exec rm -rf "{}" \;
```

Then edit `config.json` to your needs

And then edit `todo.rb`, so that it looks like:

Run the cron often:

```
*/5 * * * * cd /home/poil/my_fav_scripts/webwatchr; ruby webwatchr.rb
```

# Supported websites

* Bluesky
* Bandcamp merch pages
* Package tracking (DHL, Colissimo, i-parcel, Royalmail, PostNL, UPS, USPS, etc.)
* [Noquarterprod](https://www.noquarterprod.com)
* [Qwertee](https://www.qwertee.com)
* many many more

Some of these have been such a pain in the ass to scrape, I resorted to use their (usually terrible) APIs (ie: USPS)

# Add a new site to watch

## Watch the whole HTML source of a page

The file `lib/site.rb` provide two base methods you can choose from:

* `SimpleString`, if you're interested in checking when a string changes
* `Articles`, when you're interested in new "articles" showing up (but, for example, don't care that old articles disappear)


In both case, `get_content()` is the one that will be run to generate what needs to be diff'ed.

Either directly in `todo.rb`, or as a standalone file in `sites/`, you could declare a new class

```
class MySite < Site::SimpleString
  def initialize()
    super(url: 'https://somewhere.com', every: 60*60, comment: "that cool site")
  end
  def get_content
     return @parsed_content.css('div.info').map(&:text)
  end
end
```

and add `SimpleSite.new()` to the `SITES_TO_WATCH` array in `todo.rb`.

For `Articles`, instead of returning a String, call `add_article()`.

A few other methods that are helpful to know of, if you need to do more complicated stuff (like, authentication, etc.):

* `pull_things()` is called with no arguments, and sets up `@html_content` (which by default is just the html body of the page)
* `parse_content()` is called to set up `@parsed_content` (by default, using `Nokogiri::HTML.parse()`)
* `to_html()` method is a helper for formatting your content.


## Test your new site

Run `ruby webwatchr.rb -s mysite.rb -t -v`

It will run, and display what it would alert you with, without updating the state.


## Force a site check, ignoring the 'wait' parameter

This can be useful to run a site update at a specific time/day with a crontab, instead of every specified amount of time. You can force update a website using the -s flag:
```bash
ruby webwatchr.rb -s lol.rb -f
```

# FAQ

## POST?

If you need to actually fetch your URL using a POST HTTP request, add `post_data` as argument to Site.new(), when instanciating your new class:

## Tests?

There is like, two! run `ruby tests/test.rb`

## Logs ?

Call `logger`, as you would a classic `Logger` object in your `mysite.rb`.

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
