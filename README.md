# WebWatchr

Silly script to periodically check webpage changes.

1. run script every minute from cron
2. pulls data for every Website to check, if the last time we did that is long ago
4. if content is different, from the last time, alerts you with the new content (email, telegram)

# Installation

```shell

$ bundle install

# if you want fancier Diffs, for DiffString objects, apt install ruby-diffy

git clone https://github.com/conchyliculture/webwatchr/
cd webwatchr

And then edit `todo.rb`, so that it looks like:

Run the cron often:

```
*/5 * * * * cd /home/poil/my_fav_scripts/webwatchr; ruby webwatchr.rb
```

# Supported websites

* Bluesky
* Bandcamp merch pages
* Package tracking (DHL, Colissimo, i-parcel, Royalmail, PostNL, UPS, USPS, etc.)
* many many more

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

