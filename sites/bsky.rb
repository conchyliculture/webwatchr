require_relative "../lib/site"
require "mechanize"

class BskyBase < Site::Articles
  API_PUBLIC_HOSTS = [
    'public.api.bsky.app'
  ].freeze
  API_PRIVATE_HOSTS = [
    'oysterling.us-west.host.bsky.network',
    'amanita.us-east.host.bsky.network'
  ].freeze

  def _get_bearer()
    url = "https://bsky.social/xrpc/com.atproto.server.createSession"
    data = {
      "identifier" => @username,
      "password" => @password,
      "authFactorToken" => "",
      "allowTakendown" => true
    }
    headers = {
      "content-type" => "application/json"
    }
    resp = @mechanize.post(url, data.to_json, headers)
    j = JSON.parse(resp.body)
    begin
      return j['accessJwt']
    rescue StandardError => e
      raise Site::ParseError "Error while logging in #{e}"
    end
  end

  def _api_get(path, headers: nil)
    last_api_error = nil
    api_hosts = @bearer ? API_PRIVATE_HOSTS : API_PUBLIC_HOSTS
    api_hosts.shuffle.each do |api_host|
      url = "https://#{api_host}#{path}"
      begin
        resp = @mechanize.get(url, [], nil, headers)
      rescue StandardError => e
        last_api_error = e
        logger.debug("Got error with querying #{path} for API endpoint #{api_host}, trying another one")
        next
      end
      return resp
    end
    raise Site::ParseError, "Error querying #{path}: #{last_api_error}"
  end

  def _profile_to_did(account)
    path = "/xrpc/com.atproto.identity.resolveHandle?handle=#{account}"
    resp = _api_get(path)
    return JSON.parse(resp.body)['did']
  end

  def _article_from_post(post)
    post_id = post["uri"].split("/")[-1]
    text = post['record']['text']
    art = {
      "id" => post["uri"],
      "url" => "https://bsky.app/profile/#{@account}/post/#{post_id}",
      "title" => "#{post['record']['createdAt']}: #{text}"
    }

    if post["embed"]
      case post["embed"]["$type"]
      when "app.bsky.embed.images#view"
        images = post["embed"]["images"].sort_by { |image| (image["aspectRatio"] || { 'height' => 0 })["height"] }
        case images.size
        when 0
          # noop
        when 1
          art['img_src'] = images[0]["thumb"]
        else
          art['img_src'] = images[1]["thumb"]
        end
      end
    end

    return art
  end
end

class BskyAccount < BskyBase
  def initialize(account:, regex: nil, username: nil, password: nil, reposts: false, every: 30 * 60)
    super(
      url: "https://bsky.app/profile/#{account}",
      every: every
    )
    @reposts = reposts
    @account = account
    @mechanize = Mechanize.new()
    @regex = regex
    @username = username
    @password = password
    @json_results_key = "feed"
  end

  def pull_things
    did = _profile_to_did(@account)
    path = "/xrpc/app.bsky.feed.getAuthorFeed?actor=#{did}&filter=posts_and_author_threads&limit=30"
    resp = _api_get(path)
    @parsed_content = JSON.parse(resp.body)
  end

  def get_content
    @parsed_content['feed'].each do |p|
      post = p['post']
      text = post['record']['text']
      next if @regex and (text !~ @regex)
      next if !@reposts and (post['author']['handle'] != @account)

      art = _article_from_post(post)
      add_article(art)
    end
  end
end

class BskySearch < BskyBase
  def initialize(keyword:, username: nil, password: nil, reposts: false, every: 30 * 60)
    super(
      url: "https://bsky.app/search?#{keyword}",
      every: every
    )
    @reposts = reposts
    @keyword = keyword
    @mechanize = Mechanize.new()
    #  @mechanize.log = logger
    @username = username
    @password = password
    @json_results_key = "posts"
    raise StandardError, 'Need both username & password to run searches' unless @password and @username
  end

  def pull_things
    @bearer ||= _get_bearer()
    headers = {
      "authorization" => "Bearer #{@bearer}"
    }
    resp = _api_get("/xrpc/app.bsky.feed.searchPosts?q=#{@keyword}&limit=30&sort=top", headers: headers)
    @parsed_content = JSON.parse(resp.body)
    f = File.new("/tmp/bskyyy", "w")
    f.write(resp.body)
    f.close
  end

  def get_content
    @parsed_content['posts'].each do |post|
      add_article(_article_from_post(post))
    end
  end
end
