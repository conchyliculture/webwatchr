require_relative "../lib/site.rb"

class Twitter < Site::Articles

    def initialize(account:, regex:nil, with_replies:true, no_retweets:false, every: 60*60 ,test: false, nitter_instance: "nitter.fdn.fr")
        @regex = regex
        @no_retweets = no_retweets
        @account = account
        if regex.class == String
          @regex = /#{regex.class}/i
        end
        super(url: "https://#{nitter_instance}/#{account}#{with_replies ? '/with_replies' : ''}", every: every, test: test)
    end

    def add_art(url, txt)
        add_article({
            "id" => url,
            "url"=> url,
            "img_src" => nil,
            "title" => txt.strip()
        })
    end

    def get_content()
        @parsed_content.css('div.timeline-item').each do |tweet|
            text = tweet.css('div.tweet-content')[0].text
            if @no_retweets and tweet.css('div.retweet-header').size() > 0
              next
            end
            tweet_uri = URI('https://twitter.com'+tweet.css('a.tweet-link')[0]['href'])
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
