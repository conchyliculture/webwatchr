require_relative "../lib/site.rb"

class Twitter < Site::Articles

    def initialize(account:, regex:nil, no_retweets:false, every: ,test: false)
        @regex = regex
        @no_retweets = no_retweets
        @account = account
        if regex.class == String
          @regex = /#{regex.class}/i
        end
        super(url: "https://mobile.twitter.com/#{account}", every: every, test: test)
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
        @parsed_content.css('table.tweet').each do |tweet|
            text = tweet.css('div.tweet-text')[0].text
            if @no_retweets and not tweet.attr('href').start_with?("/#{@account}/")
              next
            end
            tweet_uri = URI('https://twitter.com'+tweet.attr('href'))
            tweet_url = "https://twitter.com"+tweet_uri.path

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

if __FILE__== $0
  Twitter.new(
     account: "mobile_test_2",
      every: 6*60*60,
      test: true,
      no_retweets: true
  ).update
end
