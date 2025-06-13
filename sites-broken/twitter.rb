require_relative "../webwatchr/site"

class Twitter < Site::Articles
  def initialize(account:, regex: nil, no_retweets: false, every: 60 * 60, nitter_instance: "nitter.unixfox.eu")
    super(
      comment: "Twitter: #{account}",
      url: "https://#{nitter_instance}/#{account}",
      every: every
    )

    @regex = regex
    @no_retweets = no_retweets
    @account = account
    if regex.instance_of?(String)
      @regex = /#{regex.class}/i
    end
    @nitter_instances = get_working_nitters
    if nitter_instance
      @nitter_instances.prepend(nitter_instance)
    end

    @extra_headers = {
      'Accept-Language' => "en-US,en;q=0.5"
    }
    @state_file = ".lasts/last-twitter_#{account.downcase}"
  end

  def get_email_subject()
    return "Update from Twitter #{@account}"
  end

  def get_working_nitters
    cache = ".cached_nitters"
    if not File.exist?(cache) or (Time.now() - File.mtime(cache)) > 1000
      url = "https://status.d420.de/api/v1/instances"
      puts "Pulling instances from #{url}" if $VERBOSE
      text = Net::HTTP.get(URI.parse(url))
      while text[0] != "{"
        puts "Error pulling data from #{url}, got: #{text}"
        sleep(10)
        text = Net::HTTP.get(URI.parse(url))
      end
      f = File.new(cache, 'w+')
      f.write(text)
      f.close
    else
      puts "Reading instances from #{cache}" if $VERBOSE
      text = File.read(cache)
    end
    j = JSON.parse(text)
    return j["hosts"].select { |h| h['healthy'] }.map { |h| h['domain'] }
  end

  def add_art(url, txt)
    add_article({
                  "id" => url,
                  "url" => url,
                  "img_src" => nil,
                  "title" => txt.strip()
                })
  end

  def pull_things
    @nitter_instances.each do |nitter|
      path = @url.gsub("https://nitter_instance/", "")
      url = URI.parse("https://#{nitter}/#{path}")
      @html_content = fetch_url1(url)
      @parsed_content = parse_content(@html_content)
    rescue StandardError => e
      logger.debug("While fetching #{url} we got #{e}")
    end
    logger.debug("no more instances to try :'(")
  end

  def parse_content(html)
    parsed = Nokogiri::HTML.parse(html)
    if parsed.css('noscript').empty? && (parsed.css('noscript')[0].text =~ /Please turn JavaScript on and reload the page./)
      raise Site::ParseError, "Instance requires javascript tests"
    end
    if parsed.text =~ /Instance has been rate limited/
      raise Site::ParseError, "Instance has been rate limited"
    end

    return parsed
  end

  def get_content()
    return unless @parsed_content

    @parsed_content.css('div.timeline-item:not(.unavailable)').each do |tweet|
      unless tweet.css('div.tweet-content')[0]
        next
      end

      text = tweet.css('div.tweet-content')[0].text
      if @no_retweets and tweet.css('div.retweet-header').empty?
        next
      end

      tweet_uri = URI("https://twitter.com#{tweet.css('a.tweet-link')[0]['href']}")
      tweet_url = "https://twitter.com#{tweet_uri.path}"

      if @regex
        if text =~ @regex
          add_art(tweet_url, text)
        end
      else
        add_art(tweet_url, text)
      end
    end
  end
end

if __FILE__ == $0
  Twitter.new(
    account: "mobile_test_2",
    test: true,
    no_retweets: true
  )
end
