require_relative "../lib/site.rb"

class Twitter < Site::Articles

    def initialize(account: , regex:nil ,every: ,test: false)
        @regex = regex
        if regex.class == String
          @regex = /#{regex.class}/i
        end
        super(url: "https://twitter.com/#{account}", every: every, test: test)
    end

    def add_art(url, txt)
        add_article({
            "id" => url,
            "url"=> url,
            "img_src" => nil,
            "title" => txt
        })
    end

    def get_content()
        @parsed_content.css('div.tweet').each do |tweet|
            text = tweet.css('p.TweetTextSize')[0].text
            tweet_url = 'https://twitter.com'+tweet.css('a.tweet-timestamp')[0].attr('href')
            if @regex 
              if text=~@regex
                add_art(tweet_url, text)
              end
            else
                add_art(tweet_url, text)
            end
        end
    end
end

Twitter.new(
    account: "twitter",
    every: 6*60*60,
    test: __FILE__== $0,
).update
