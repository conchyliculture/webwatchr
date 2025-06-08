require_relative "../webwatchr/site"
require "mechanize"

class BskyBase < Site::Articles
  API_PUBLIC_HOSTS = [
    'public.api.bsky.app'
  ].freeze
  API_PRIVATE_HOSTS = [
    'scalycap.us-west.host.bsky.network'
    #'oysterling.us-west.host.bsky.network'
    #    'amanita.us-east.host.bsky.network'
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

  def _api_get(path, params: [], headers: nil)
    api_hosts = @bearer ? API_PRIVATE_HOSTS : API_PUBLIC_HOSTS
    api_host = api_hosts.sample
    url = "https://#{api_host}#{path}"
    resp = @mechanize.get(url, params, nil, headers)
    return resp
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
  # Parses Bluesky "profile" pages and returns every post
  #
  # ==== Examples
  #
  # Webwatchr::Main.new do
  #     update BskyAccount do
  #          account "theonion.com"
  #          # Optional settings
  #          set "reposts", false   # Disable reposts
  #          set "regex", /fun/     # Only posts where the text matches the regex
  #     end
  #     ....
  # end

  attr_accessor :reposts, :regex

  def account(account)
    @account = account
    @url = "https://bsky.app/profile/#{account}"
    self
  end

  def initialize
    super()
    @reposts = true
    @mechanize = Mechanize.new()
    @json_results_key = "feed"
  end

  def pull_things
    did = _profile_to_did(@account)
    path = "/xrpc/app.bsky.feed.getAuthorFeed?actor=#{did}&filter=posts_and_author_threads&limit=30"
    resp = _api_get(path)
    @parsed_content = JSON.parse(resp.body)
    f = File.open("/tmp/qsd", 'w')
    f.write(resp.body)
    f.close
  end

  def get_content
    @parsed_content['feed'].each do |p|
      post = p['post']
      text = post['record']['text']
      next if @regex and (text !~ @regex)

      next if !@reposts && (post['author']['handle'] != @account)

      art = _article_from_post(post)
      add_article(art)
    end
  end
end

class BskySearch < BskyBase
  # Runs a search on Bluesky for a keyword
  #
  # ==== Examples
  #
  # Webwatchr::Main.new do
  #     update BskyAccount do
  #          keyword "#danemark"
  #          # Mandatory settings, you need to be logged in to search
  #          set "username", "username"
  #          set "password", "password"
  #     end
  #     ....
  # end
  attr_accessor :username, :password

  def keyword(keyword)
    @keyword = keyword
    @url = "https://bsky.app/search?#{keyword}"
    self
  end

  def initialize
    super()
    @mechanize = Mechanize.new()
    @json_results_key = "posts"
  end

  def pull_things
    raise StandardError, 'Need both username & password to run searches' unless @password and @username

    @bearer ||= _get_bearer()
    headers = {
      "authorization" => "Bearer #{@bearer}"
    }

    params = { "q" => "#danemark", "limit" => 30, "sort" => "top" }
    resp = _api_get("/xrpc/app.bsky.feed.searchPosts", params: params.to_a, headers: headers)
    @parsed_content = JSON.parse(resp.body)
  end

  def get_content
    @parsed_content['posts'].each do |post|
      add_article(_article_from_post(post))
    end
  end
end
