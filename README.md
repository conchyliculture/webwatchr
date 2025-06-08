# WebWatchr

Silly script to periodically check webpage changes.

1. run script every minute from cron
2. pulls data for every Website to check, if the last time we did that is long ago
4. if content is different, from the last time, alerts you with the new content (email, telegram)

# Installation

```shell

$ gem install webwatchr

# if you want fancier Diffs, for DiffString objects, apt install ruby-diffy
```

And then make your own `dsl.rb` script. Example:

```ruby
require "webwatchr"

class SomeSimpleSite < Site::SimpleString
  def initialize()
    @url = "https://somesimplesite.com/shops"
    super()
  end

  # Implement this function, to return what you want to compare every run
  def get_content
    res = ""
    @parsed_content.css("div.shop-main a").map do |a|
      url = "https://somesimplesite.com/shop/#{a['href']}"
      if a.css('img')[0]['src'] == "soldout.png"
        next
      end

      res << "#{url}\n"
    end
    res == "" ? nil : res
  end
end

Webwatchr::Main.new do
  # Some configuration, first for the alerting

  # Send emails
  add_default_alert :email do
    set :smtp_port, 25
    set :smtp_server, "localhost"
    set :from_addr, "webwatchr@domain.eu"
    set :dest_addr, "admin@domain.eu"
  end

  # Use telegram bot to send you messages
  add_default_alert :telegram do
    set :token, "12345:LONGTOKEN09876543"
    set :chat_id, 1234567890
  end

  # # Just outputs update to the terminal
  # add_default_alert :stdout

  update BskySearch do
    set "username", "toto"
    set "password", "toto"
    keyword "#danemark"
  end

  update SomeSimpleSite

  update PostCH do
    track_id "LS234567890CH"
  end
end
```

Run the cron often:

```
*/5 * * * * cd /home/poil/my_fav_scripts/; ruby dsl.rb
```

# Supported websites

* Bluesky
* Bandcamp merch pages
* Package tracking (DHL, Colissimo, i-parcel, Royalmail, PostNL, UPS, USPS, etc.)
* etc.

# Add a new site to watch

## Watch the whole HTML source of a page


## Test your new site


## Force a site check, ignoring the 'wait' parameter

This can be useful to run a site update at a specific time/day with a crontab, instead of every specified amount of time. You can force update a website using the -s flag:
```bash
ruby webwatchr.rb -s SiteClass
```

# FAQ

## POST?

If you need to actually fetch your URL using a POST HTTP request, add `post_data` as argument to Site.new(), when instanciating your new class:

## Tests?

There is like, two! run `rake`

## Logs ?

Call `logger`, as you would a classic `Logger` object in your `mysite.rb`.

## Alerting

Email is the main method of alerting, but you can also set webwatchr to talk to you on Telegram through a bot.

First make a bot and grab a token following the [Telegram procedure](https://core.telegram.org/bots#6-botfather).

You also need to know the `chat_id` for its discussion with you. The code in [there](https://github.com/atipugin/telegram-bot-ruby/blob/master/examples/bot.rb) can help you.

