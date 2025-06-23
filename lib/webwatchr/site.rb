require "digest/md5"
require "fileutils"
require "json"
require "logger"
require "net/http"
require "nokogiri"
require_relative "./logger"

# Base class for a Site to be watched
#
# Handles pulling data from websites as well as storing the state and when to update next.
#
# == Overview
#
# - update() is called, which loads the saved state file
# - do_stuff() is called and checks whether or not we should update (aka: if the last time was long enough ago)
# - if it is time, we call pull_things(), which can be overloaded, but by default just ;
#    - fetches @url, and stores it in @website_html
#    - parses @website_html, with Nokogiri, into @parsed_html
#    - calls extract_content(), which is the method that extract what we are interested in the webpage.
#     Its results will get compared with the previous execution's results.
#     This is the one you should reimplement at the very least (unless you want to compare against the whole HTML body).
#  - get_diff() is the method that will do the comparison, and its return value, if not nil, will trigger alerting
#  - Each Alerter object in @alerters will be called, if needed.
class Site
  include Loggable
  class ParseError < StandardError
  end

  class RedirectError < StandardError
  end

  HTML_HEADER = "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n".freeze
  DEFAULT_USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'.freeze

  attr_accessor :url, :alerters, :rand_sleep, :update_interval, :lastdir, :cache_dir, :state_file, :comment

  attr_writer :name

  def set(name, value)
    instance_variable_set("@#{name}", value)
    self
  end

  def name
    @url.dup
  end

  def self.create(&block)
    if block
      new.instance_eval(&block)
    else
      new
    end
  end

  def method_missing(attr, *args) # rubocop:disable Style/MissingRespondToMissing
    if args.empty?
      instance_variable_get("@#{attr}")
    else
      instance_variable_set("@#{attr}", *args)
      self
    end
  end

  def initialize()
    @useragent = Site::DEFAULT_USER_AGENT
    @extra_headers = {}
    @alerters = []
    @alert_only = []
    @http_ver = 1
    @rand_sleep = 0
    @did_stuff = false
    @update_interval = 3600
  end

  def display_optional_state
    puts "We parsed the website and extracted content #{@content}"
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
    raise StandardError, "We called generate_html_content, but there is no @content" unless @content

    message_html = Site::HTML_HEADER.dup
    message_html += @content
    return message_html
  end

  # Helper methods to generate Telegram messages
  def generate_telegram_message_pieces()
    raise StandardError, "We called generate_telegram_message_pieces, but there is no @content" unless @content

    return [@content]
  end

  # Uses Curb to query websites with HTTP/2
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
      when "301", "302", "303"
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

        logger.debug "Redirecting to #{location}"
        return fetch_url(location, max_redir: max_redir - 1)
      end

      html = response.body

      if html && (html =~ /meta http-equiv="refresh" content="0;URL='(.*)'/)
        if max_redir == 0
          raise Site::RedirectError
        end

        url = "#{uri.scheme}://#{uri.hostname}:#{uri.port}#{::Regexp.last_match(1)}"
        logger.debug "Redirecting to #{location}"
        return fetch_url(url, max_redir: max_redir - 1)
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
    if @state_file and File.exist?(@state_file)
      begin
        return JSON.parse(File.read(@state_file), create_additions: true)
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

  # Takes the old state file, and updates it with the values passed in hash
  def update_state_file(hash)
    previous_state = load_state_file()
    state = previous_state.update(hash)
    save_state_file(state)
  end

  def alert()
    logger.debug "Alerting new stuff"
    @alerters.each do |alerter|
      if @alert_only.empty? or @alert_only.include?(alerter.class::IDENTIFIER)
        alerter.alert(self)
      end
    end
  end

  def alert_only(alerter_identifiers)
    if alerter_identifiers.instance_of?(Symbol)
      @alert_only = [alerter_identifiers]
    elsif alerter_identifiers.instance_of(Array)
      @alert_only = alerter_identifiers
    else
      raise StandardError, "unknown type of provided alerter identifier #{alerter_identifiers}"
    end
    self
  end

  # This method compares the previous stored content, with the new one, and returns what is new.
  def get_diff()
    return @content
  end

  def update(cache_dir:, last_dir:, test: false)
    raise StandardError, "Didn't set URL for site #{self}" unless @url

    md5 = Digest::MD5.hexdigest(@url)
    @cache_dir = File.join(cache_dir, "cache-#{URI.parse(@url).hostname}-#{md5}")
    @state_file = File.join(last_dir, "last-#{URI.parse(@url).hostname}-#{md5}")
    @test = test
    logger.debug "using #{@state_file} to store updates, and #{@cache_dir} for Cache"

    do_stuff()
  rescue Site::RedirectError
    msg = "Error parsing page #{@url}, too many redirects"
    msg += ". Will retry in #{@update_interval} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "time" => Time.now.to_i, "wait_at_least" => @update_interval + 30 * 60 })
  rescue Site::ParseError => e
    msg = "Error parsing page #{@url}"
    if e.message
      msg += " with error : #{e.message}"
    end
    msg += ". Will retry in #{@update_interval} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "time" => Time.now.to_i, "wait_at_least" => @update_interval + 30 * 60 })
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::ReadTimeout, OpenSSL::SSL::SSLError, Net::OpenTimeout => e
    msg = "Network error on #{@url}"
    if e.message
      msg += " : #{e.message}"
    end
    msg += ". Will retry in #{@update_interval} + 30 minutes"
    logger.error msg
    warn msg
    update_state_file({ "time" => Time.now.to_i, "wait_at_least" => @update_interval + 30 * 60 })
  end

  def extract_content()
    return @website_html
  end

  # By default, we pull html from the @url, we parse it with Nokogiri
  def pull_things()
    @website_html = fetch_url(@url)
    @parsed_html = parse_noko(@website_html)
    @content = extract_content()
  end

  def do_stuff()
    # Prepare previous_state, with defaults, that can be overriden with what we may find in the state_file
    previous_state = {
      "time" => -9_999_999_999_999,
      "content" => nil
    }
    old_state = load_state_file()
    delay_between_updates = old_state["wait_at_least"] || @update_interval || 60
    if old_state
      previous_state.update(old_state)
    end

    if @test or (Time.now().to_i >= previous_state['time'] + delay_between_updates)
      if @rand_sleep > 0 and not @test
        logger.info "Time to update #{@url} (sleeping #{@rand_sleep} sec)"
        sleep(@rand_sleep)
      else
        logger.info "Time to update #{@url}"
      end

      pull_things()

      new_stuff = get_diff()
      @did_stuff = true
      if new_stuff
        if @test
          logger.info "Would have alerted with new stuff:\n#{new_stuff}"
        else
          alert()
        end
      else
        logger.info "Nothing new for #{@url}"
        if @test
          display_optional_state()
        end
      end
    else
      @did_stuff = true
      logger.info "Too soon to update #{@url}"
    end
  end

  class SimpleString < Site
    class ListResult < ResultObject
      attr_accessor :elements

      def initialize(*elements)
        @elements = elements
        super()
      end

      def <<(elem)
        @elements << elem
      end

      def to_telegram()
        msg = []
        @elements.each do |elem|
          msg << " * #{elem}"
        end
        return msg.join("\n")
      end

      def to_s
        return to_telegram
      end

      def to_html()
        msg = ["<ul>"]
        @elements.each do |elem|
          msg << "<li>#{elem}</li>"
        end
        msg << ["</ul>"]
        return msg.join("\n")
      end

      def to_json(*args)
        {
          JSON.create_id => self.class.name,
          'elements' => @elements
        }.to_json(*args)
      end

      def self.json_create(object)
        new(*object['elements'])
      end

      def ==(other)
        self.class == other.class &&
          @elements.sort == other.elements.sort
      end
    end

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

    def get_diff()
      @content ||= extract_content()
      previous_content = load_state_file()["content"]
      return nil if @content == previous_content

      update_state_file(
        {
          "time" => Time.now.to_i,
          "wait_at_least" => @update_interval,
          "content" => @content
        }
      )
      return @content
    end

    def generate_html_content()
      return nil unless @content

      message_html = Site::HTML_HEADER.dup
      if @content.is_a?(ResultObject)
        message_html += @content.to_html
      else
        message_html += @content
      end
      return message_html
    end

    def generate_telegram_message_pieces()
      return [@content.is_a?(ResultObject) ? @content.to_telegram : @content]
    end
  end

  ## For use when you want to parse a site, and are only interested is having
  # a nice looking "Diff" between the new and the previous state
  #  class DiffString < SimpleString
  #    begin
  #      require "diffy"
  #
  #      def generate_html_content()
  #        diff_html = Site::HTML_HEADER.dup
  #        diff_html += "<head><style>"
  #        diff_html += Diffy::CSS
  #        diff_html += "</style><body>"
  #        diff_html += @diffed.to_s(:html)
  #        diff_html += "</body></html>"
  #        return diff_html
  #      end
  #
  #      def get_differ(previous, new)
  #        return Diffy::Diff.new(previous, new)
  #      end
  #    rescue LoadError
  #      require "test/unit/diff"
  #      def generate_html_content()
  #        diff_html = Site::HTML_HEADER.dup
  #        diff_html += @diffed.to_s
  #        diff_html += "</body></html>"
  #        return diff_html
  #      end
  #
  #      def get_differ(previous, new)
  #        return new unless previous
  #
  #        return Test::Unit::Diff.unified(previous, new)
  #      end
  #    end
  #
  #    def get_diff()
  #      new_stuff = nil
  #      @content = extract_content()
  #      unless @content
  #        return nil
  #      end
  #
  #      if @content != previous_content
  #        @diffed = get_differ(previous_content, @content)
  #        new_stuff = @diffed.to_s
  #      end
  #      return new_stuff
  #    end
  #  end

  ## For use when you want to parse a site that has Articles
  # And you want to know when knew, previously unseen Articles appear.
  # For example, a shop.
  #
  # You need to make sure to call add_article() with instances of Article.
  class Articles < Site
    class Article < Hash
    end

    def initialize
      super
      @articles = []
      @found_articles = 0
    end

    def content
      log.error("Do not use site.content on an instance of Site::Articles in #{caller}")
      return @articles
    end

    def display_optional_state
      puts "We parsed the website and extracted #{@found_articles} articles"
    end

    def validate(article)
      id = article['id']
      raise StandardError, "Article needs an \"id\", which is used as identifier" unless id

      raise StandardError, "\"id\" key needs to be a String and not #{id.class}" unless id.is_a?(String)
    end

    def add_article(article)
      logger.debug "Found article #{article['id']}"
      @found_articles += 1
      validate(article)
      article['_timestamp'] = Time.now().to_i
      @articles << article unless @articles.map { |art| art['id'] }.include?(article['id'])
    end

    def extract_articles()
      raise StandardError, "Please implement extract_articles(). Use @parsed_html and call add_article()."
    end

    def get_diff()
      extract_articles()
      unless @articles
        return nil
      end

      new_stuff = @articles
      previous_articles = load_state_file()["articles"]
      if previous_articles
        previous_ids = previous_articles.map { |art| art['id'] }
        new_stuff = @articles.delete_if { |article| previous_ids.include?(article['id']) }
      end
      update_state_file(
        {
          "time" => Time.now.to_i,
          "wait_at_least" => @update_interval,
          "articles" => (previous_articles || []).concat(@articles)
        }
      )
      if (not new_stuff) or new_stuff.empty?
        return nil
      end

      return new_stuff
    end

    # Here we want to store every article we ever found
    def update_state_file(hash)
      previous_state = load_state_file()
      state = previous_state.update(hash)
      save_state_file(state)
    end

    def generate_html_content()
      message_html = Site::HTML_HEADER.dup
      message_html << "<ul style='list-style-type: none;'>\n"
      @articles.each do |article|
        msg = "<li id='#{article['id']}'>"
        if article['url']
          msg += "<a href='#{article['url']}'>"
        end
        if article["img_src"]
          msg += "<img style='width:100px' src='#{article['img_src']}'/>"
        end
        if article["title"]
          msg += article['title'].to_s
        end
        if article["url"]
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
      @articles.each do |article|
        line = article["title"]
        if article["url"]
          if line
            line += ": #{article['url']}"
          else
            line = article["url"]
          end

          line += ": #{article['url']}"
        end
        msg_pieces << line
      end
      return msg_pieces
    end
  end
end
