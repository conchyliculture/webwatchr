require_relative "../lib/site"
require "mechanize"

class Bsky < Site::Articles
  def initialize(account:, regex: nil, reposts: false, every: 30 * 60)
    super(
      url: "https://bsky.app/profile/#{account}",
      every: every
    )
    @reposts = reposts
    @account = account
    @mechanize = Mechanize.new()
    @regex = regex
  end

  def _get_api_host
    api_host = "public.api.bsky.app"
    if @bearer
      api_host = "oysterling.us-west.host.bsky.network"
    end
    return api_host
  end

  def _profile_to_did(account)
    url = "https://#{_get_api_host()}/xrpc/com.atproto.identity.resolveHandle?handle=#{account}"
    resp = @mechanize.get(url)
    return JSON.parse(resp.body)['did']
  end

  def pull_things
    did = _profile_to_did(@account)
    url = "https://#{_get_api_host()}/xrpc/app.bsky.feed.getAuthorFeed?actor=#{did}&filter=posts_and_author_threads&limit=30"
    resp = @mechanize.get(url)
    @parsed_content = JSON.parse(resp.body)
  end

  def get_content
    @parsed_content['feed'].each do |p|
      post = p['post']
      post_id = post["uri"].split("/")[-1]
      text = post['record']['text']
      art = {
        "id" => post["uri"],
        "url" => "https://bsky.app/profile/#{@account}/post/#{post_id}",
        "title" => "#{post['record']['createdAt']}: #{text}"
      }

      next if @regex and (text !~ @regex)

      next if !@reposts and (post['author']['handle'] != @account)

      add_article(art)
    end
  end
end
