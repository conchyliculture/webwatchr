require "digest/md5"
require "fileutils"
require "json"
require "logger"
require "net/http"
require "nokogiri"
require_relative "./config"
require_relative "./logger"

class Site
  include Loggable
  class ParseError < StandardError
  end

  class RedirectError < StandardError
  end

  HTML_HEADER = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n".freeze
  DEFAULT_USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'.freeze

  attr_accessor :state_file, :url, :wait, :name, :test

  def initialize(url:, every: nil, post_data: nil, post_json: nil, comment: nil, useragent: nil, http_ver: 1, alert_only: [], rand_sleep: 0)
    @config = Config.config || { "last_dir" => File.join(File.dirname(__FILE__), "..", ".lasts") }
    @name = url.dup()
    @comment = comment
    @post_data = post_data
    @post_json = post_json
    @test = false
    @url = url
    @useragent = useragent || Site::DEFAULT_USER_AGENT
    @extra_headers = {}
    @alert_only = alert_only
    @http_ver = http_ver
    @rand_sleep = rand(rand_sleep).floor

    md5 = Digest::MD5.hexdigest(url)
    @state_file_name ||= "last-#{URI.parse(url).hostname}-#{md5}"
    @cache_dir ||= "cache-#{URI.parse(url).hostname}-#{md5}"
    @state_file = if @config and @config["last_dir"]
                    File.join(@config["last_dir"], @state_file_name)
                  else
                    File.join(".lasts", @state_file_name)
                  end
    @cache_dir = if @config and @config["cache_dir"]
                   File.join(@config["cache_dir"], @cache_dir)
                 else
                   File.join(".cache", @cache_dir)
                 end
    logger.debug "using #{@state_file} to store updates, and #{@cache_dir} for Cache"
    state = load_state_file()
    @wait = every || state["wait"] || 60 * 60

    @did_stuff = false
  end

  def get_cache_dir()
    FileUtils.mkdir_p(@cache_dir)
    return @cache_dir
  end

  def set_http_header(key, value)
    @extra_headers[key] = value
  end

  def fetch_url(url, max_redir: 10)
    if @http_ver == 2
      return fetch_url2(url)
    end

    return fetch_url1(url, max_redir: max_redir)
  end

  # Helper methonds for generating HTML emails

  def get_email_url()
    return @url
  end

  def get_email_subject()
    subject = "Update from #{self.class}"
    if @comment
      subject += " (#{@comment})"
    end
    return subject
  end

  def generate_html_content()
    return nil unless @content

    message_html = Site::HTML_HEADER.dup
    message_html += @content
    return message_html
  end

  # Helper methods to generate Telegram content
  def generate_telegram_message_pieces()
    return [@content]
  end

  def fetch_url2(url)
    require "curb"

    if @post_data
      cmethod = Curl::Easy.method(:http_post)
      params = [url, @post_data]
    else
      cmethod = Curl::Easy.method(:new)
      params = [url]
    end

    c = cmethod.call(*params) do |curl|
      curl.set(:HTTP_VERSION, Curl::HTTP_2_0)
      if @useragent
        curl.headers['User-Agent'] = @useragent
      end
      curl.verbose = true
      @extra_headers.each do |k, v|
        curl.headers[k] = v
      end
    end

    c.perform
    return c.body_str
  end

  def fetch_url1(url, max_redir: 10)
    html = ""
    uri = URI(url)
    req = nil
    http_o = Net::HTTP.new(uri.host, uri.port)
    http_o.use_ssl = (uri.scheme == 'https')
    http_o.set_debug_output $stderr if $VERBOSE
    http_o.start do |http|
      if @post_data
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(@post_data)
      elsif @post_json
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = if @post_json.instance_of?(String)
                     @post_json
                   else
                     @post_json.to_json
                   end

      else
        req = Net::HTTP::Get.new(uri)
      end
      if @useragent
        req["User-Agent"] = @useragent
      end
      @extra_headers.each do |k, v|
        req[k] = v
      end
      response = http.request(req)
      case response.code
      when "301", "302"
        if max_redir == 0
          raise Site::RedirectError
        end

        location = response["Location"]
        unless location.start_with?("http")
          location = if location.start_with?("/")
                       "#{uri.scheme}://#{uri.hostname}:#{uri.port}#{location}"
                     else
                       "#{uri.scheme}://#{uri.hostname}:#{uri.port}/#{location}"
                     end
        end

        @url = location
        logger.debug "Redirecting to #{location}"
        return fetch_url(location, max_redir: max_redir - 1)
      end

      html = response.body

      if html && (html =~ /meta http-equiv="refresh" content="0;URL='(.*)'/)
        if max_redir == 0
          raise Site::RedirectError
        end

        @url = "#{uri.scheme}://#{uri.hostname}:#{uri.port}#{::Regexp.last_match(1)}"
        logger.debug "Redirecting to #{location}"
        return fetch_url(@url, max_redir: max_redir - 1)
      end

      html = if html and response["Content-Encoding"]
               html.force_encoding(response["Content-Encoding"])
             else
               html.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
             end
    end
    logger.debug "Fetched #{url}"
    return html
  end

  def parse_content(html)
    return parse_noko(html)
  end

  def parse_noko(html)
    noko = Nokogiri::HTML(html)
    meta = noko.css("meta")
    meta.each do |m|
      if m['charset']
        html = html.force_encoding(m['charset'])
      end
    end
    return Nokogiri::HTML(html)
  end

  def load_state_file()
    if File.exist?(@state_file)
      begin
        return JSON.parse(File.read(@state_file), creater_additions: true)
      rescue JSON::ParserError
      end
    end
    return {}
  end

  def save_state_file(hash)
    File.open(@state_file, "w") do |f|
      f.write JSON.pretty_generate(hash)
    end
  end

  def update_state_file(hash)
    previous_state = load_state_file()
    previous_state.update({
                            "time" => Time.now.to_i,
                            "url" => @url,
                            "wait" => @wait
                          })
    state = previous_state.update(hash)
    save_state_file(state)
  end

  def alert(_new_content)
    logger.debug "Alerting new stuff"
    @config["alert_procs"].each do |alert_name, p|
      if @alert_only.empty? or @alert_only.include?(alert_name)
        p.call(site: self)
      end
    end
  end

  def content()
    unless @did_stuff
      raise StandardError, 'Trying to access @content, but we have not pulled any data yet'
    end

    return @content
  end

  def get_content()
    return @html_content
  end

  def should_update?(prevous_time)
    return Time.now().to_i >= prevous_time + @wait
  end

  def get_new(_previous_content = nil)
    @content = get_content()
    return @content
  end

  def update(test: false)
    @test = test
    do_stuff()
  rescue Site::RedirectError
    msg = "Error parsing page #{@url}, too many redirects"
    msg += ". Will retry in #{@wait} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "wait" => @wait + 30 * 60 })
  rescue Site::ParseError => e
    msg = "Error parsing page #{@url}"
    if e.message
      msg += " with error : #{e.message}"
    end
    msg += ". Will retry in #{@wait} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "wait" => @wait + 30 * 60 })
  rescue Errno::ECONNREFUSED, Net::ReadTimeout, OpenSSL::SSL::SSLError, Net::OpenTimeout => e
    msg = "Network error on #{@url}"
    if e.message
      msg += " : #{e.message}"
    end
    msg += ". Will retry in #{@wait} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "wait" => @wait + 30 * 60 })
  end

  def pull_things()
    @html_content = fetch_url(@url)
    @parsed_content = parse_content(@html_content)
  end

  def do_stuff()
    new_stuff = false
    previous_state = {
      "time" => -9_999_999_999_999,
      "content" => nil
    }
    state = load_state_file()
    if state
      previous_state.update(state)
    end
    previous_content = previous_state["content"]
    if should_update?(previous_state["time"]) or @test
      if @rand_sleep > 0 and not @test
        logger.info "Time to update #{@url} (sleeping #{@rand_sleep} sec)"
        sleep(@rand_sleep)
      else
        logger.info "Time to update #{@url}"
      end
      pull_things()
      new_stuff = get_new(previous_content)
      @did_stuff = true
      if new_stuff
        if @test
          logger.info "Would have sent an email with:\n#{new_stuff}"
        else
          alert(new_stuff)
          update_state_file({
                              "content" => new_stuff,
                              "previous_content" => previous_content
                            })
        end
      else
        logger.info "Nothing new for #{@url}"
      end
      update_state_file({}) unless @test
    else
      @did_stuff = true
      logger.info "Too soon to update #{@url}"
    end
  end

  class SimpleString < Site
    class ResultObject
      attr_accessor :message

      def initialize(message = '')
        @message = message
      end

      def to_telegram()
        return @message
      end

      def to_s
        return @message
      end

      def to_html()
        return @message
      end

      def to_json(*args)
        {
          JSON.create_id => self.class.name,
          'message' => @message
        }.to_json(*args)
      end

      def self.json_create(object)
        new(*object['message'])
      end

      def ==(other)
        self.class == other.class &&
          @message == other.message
      end
    end

    def get_new(previous_content = nil)
      # Is a ResultObject
      @content = get_content()
      raise StandardError, "The result of get_content() should be a ResultObject if the Site class is SimpleString" unless @content.class < ResultObject
      return nil if @content == previous_content or not @content

      return @content
    end

    def generate_html_content()
      return nil unless @content

      message_html = Site::HTML_HEADER.dup
      message_html += @content.to_html
      return message_html
    end

    def generate_telegram_message_pieces()
      return [@content.to_telegram]
    end
  end

  class DiffString < SimpleString
    begin
      require "diffy"

      def generate_html_content()
        diff_html = Site::HTML_HEADER.dup
        diff_html += "<head><style>"
        diff_html += Diffy::CSS
        diff_html += "</style><body>"
        diff_html += @diffed.to_s(:html)
        diff_html += "</body></html>"
        return diff_html
      end

      def get_differ(previous, new)
        return Diffy::Diff.new(previous, new)
      end
    rescue LoadError
      require "test/unit/diff"
      def generate_html_content()
        diff_html = Site::HTML_HEADER.dup
        diff_html += @diffed.to_s
        diff_html += "</body></html>"
        return diff_html
      end

      def get_differ(previous, new)
        return new unless previous

        return Test::Unit::Diff.unified(previous, new)
      end
    end

    def get_new(previous_content = nil)
      new_stuff = nil
      @content = get_content()
      unless @content
        return nil
      end

      if @content != previous_content
        @diffed = get_differ(previous_content, @content)
        new_stuff = @diffed.to_s
      end
      return new_stuff
    end

    def alert(_new_content)
      logger.debug "Alerting new stuff"
      @config["alert_procs"].each do |alert_name, p|
        if @alert_only.empty? or @alert_only.include?(alert_name)
          p.call({ site: self })
        end
      end
    end
  end

  class Articles < Site
    def initialize(url:, every: 60 * 60, post_data: nil, comment: nil, useragent: nil, alert_only: [], http_ver: 1, rand_sleep: 0)
      super
      @content = []
    end

    def validate(item)
      raise StandardError, "Needs at least \"id\" key" unless item["id"]

      id = item["id"]
      raise StandardError, "\"id\" key needs to be a String and not #{id.class}" unless id.is_a?(String)
    end

    def add_article(item)
      logger.debug "Found article #{item['id']}"
      validate(item)
      item["_timestamp"] = Time.now().to_i
      @content << item unless @content.map { |x| x['id'] }.include?(item['id'])
    end

    def get_new(previous_content)
      new_stuff = []
      get_content()
      unless @content
        return nil
      end

      if previous_content
        previous_ids = previous_content.map { |h| h["id"] }
        new_stuff = @content.delete_if { |item| previous_ids.include?(item["id"]) }
      else
        new_stuff = @content
      end
      if (not new_stuff) or new_stuff.empty?
        return nil
      end

      return new_stuff
    end

    def update_state_file(hash)
      hash_content = hash["content"]
      hash.delete("content")
      previous_state = load_state_file()
      previous_state.update({
                              "time" => Time.now.to_i,
                              "url" => @url,
                              "wait" => @wait
                            })
      state = previous_state.update(hash)
      if hash_content
        (previous_state["content"] ||= []).concat(hash_content)
      end
      save_state_file(state)
    end

    def generate_html_content()
      message_html = Site::HTML_HEADER.dup
      message_html << "<ul style='list-style-type: none;'>\n"
      @content.each do |item|
        msg = "<li id='#{item['id']}'>"
        if item["url"]
          msg += "<a href='#{item['url']}'>"
        end
        if item["img_src"]
          msg += "<img style='width:100px' src='#{item['img_src']}'/>"
        end
        if item["title"]
          msg += item['title'].to_s
        end
        if item["url"]
          msg += "</a>"
        end
        msg += "</li>\n"
        message_html += msg
      end
      message_html += "</ul>"
      return message_html
    end

    def generate_telegram_message_pieces()
      msg_pieces = []
      site.content.each do |item|
        line = item["title"]
        if item["url"]
          if line
            line += ": #{item['url']}"
          else
            line = item["url"]
          end

          line += ": #{item['url']}"
        end
        msg_pieces << line
      end
      return msg_pieces
    end
  end
end
