#!/usr/bin/ruby
# encoding: utf-8

require "digest/md5"
require "json"
require "logger"
require "net/http"
require "nokogiri"


class Site

    class Site::ParseError < Exception
    end

    Site::HTML_HEADER="<!DOCTYPE html>\n<meta charset=\"utf-8\">\n"

    attr_accessor :state_file, :url, :wait
    def initialize(url:, every: 60*60, post_data: nil, test: false, comment:nil)
        @logger = $logger || Logger.new(STDOUT)
        @name = url.dup()
        @comment = comment
        if @comment
            @name << " (#{@comment})"
        end
        @post_data = post_data
        @test = test
        @url = url

        md5 = Digest::MD5.hexdigest(url)
        @state_file = ".lasts/last-#{md5}"
        if $CONF and $CONF["last_dir"]
            @state_file = File.join($CONF["last_dir"] || ".", "last-#{md5}")
            @logger.debug "using #{@state_file} to store updates"
        end
        state = load_state_file()
        @wait = state["wait"] || every
    end

    def fetch_url(url)
        html = ""
        uri = URI(url)
        req = nil
        http_o = Net::HTTP.new(uri.host, uri.port)
        http_o.use_ssl = (uri.scheme == 'https')
#        http_o.set_debug_output $stderr
        http_o.start do |http|
            if @post_data
                req = Net::HTTP::Post.new(uri)
                req.set_form_data(@post_data)
            else
                req = Net::HTTP::Get.new(uri)
            end
            req["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36"
            response = http.request(req)
            html = response.body
            if html and response["Content-Encoding"]
                html = html.force_encoding(response["Content-Encoding"])
            else
                html = html.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
            end
        end
        @logger.debug "Fetched #{url}"
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
                return JSON.parse(File.read(@state_file))
            rescue JSON::ParserError
            end
        end
        return {}
    end

    def save_state_file(hash)
        File.open(@state_file,"w") do |f|
            f.write JSON.pretty_generate(hash)
        end
    end

    def update_state_file(hash)
        previous_state = load_state_file()
        previous_state.update({
            "time" => Time.now.to_i,
            "url" => @url,
            "wait" => @wait,
        })
        state = previous_state.update(hash)
        save_state_file(state)
    end


    def alert(new_stuff)
        @logger.debug "Alerting new stuff"
        $CONF["alert_proc"].call({content: format(new_stuff), name: @name})
    end

    def get_content()
        return @http_content
    end

    def should_update?(prevous_time)
        return Time.now().to_i >= prevous_time + @wait
    end

    def get_new(previous_content=nil)
        @content = get_content()
        return @content
    end

    def update()
        begin
            do_stuff()
        rescue Site::ParseError => e
            msg = "Error parsing page #{@url}"
            if e.message
                msg+=" with error : #{e.message}"
            end
            msg += ". Will retry in #{@wait} + 30 minutes"
            @logger.error msg
            $stderr.puts msg
            update_state_file({"wait" => @wait + 30*60})
        rescue Errno::ECONNREFUSED => e
            msg = "Network error on #{@url}"
            if e.message
                msg+=" : #{e.message}"
            end
            msg += ". Will retry in #{@wait} + 30 minutes"
            @logger.error msg
            $stderr.puts msg
            update_state_file({"wait" => @wait + 30*60})
        end
    end

    def do_stuff()
        new_stuff = false
        previous_state = {
            "time" => -9999999999999,
            "content" => nil,
        }
        state = load_state_file()
        if state
            previous_state.update(state)
        end
        previous_content = previous_state["content"]
        if should_update?(previous_state["time"]) or @test
            @logger.info "Time to update #{@url}" unless @test
            @http_content = fetch_url(@url)
            @parsed_content = parse_content(@http_content)
            new_stuff = get_new(previous_content)
            if new_stuff
                if @test
                    puts "Would have sent an email with #{format(new_stuff)}"
                else
                    alert(new_stuff)
                    update_state_file({"content" => new_stuff})
                end
            else
                if @test
                    puts "Nothing new"
                end
                @logger.info "Nothing new for #{@url}"
            end
        else
            @logger.info "Too soon to update #{@url}"
        end
    end

    def format(content)
        message_html = Site::HTML_HEADER.dup
        message_html += @content
        return message_html
    end

    class Site::SimpleString < Site

        def get_new(previous_content=nil)
            new_stuff = nil
            @content = get_content()
            if @content != previous_content
                new_stuff = @content
            end
            return new_stuff
        end

        def format(content)
            message_html = Site::HTML_HEADER.dup
            message_html += content
            return message_html
        end
    end

    class Site::Articles < Site

        def validate(item)
            raise Exception.new("Needs at least \"id\" key") unless item["id"]
            id = item["id"]
            raise Exception.new("\"id\" key needs to be a String and not #{id.class}") unless id.kind_of?(String)
        end

        def add_article(item)
            @logger.debug "Found article #{item['id']}"
            validate(item)
            item["_timestamp"] = Time.now().to_i
            (@content ||= []) << item
        end

        def get_new(previous_content)
            new_stuff = []
            get_content()
            unless @content
                return nil
            end
            if previous_content
                previous_ids = previous_content.map{|h| h["id"]}
                new_stuff = @content.delete_if{|item| previous_ids.include?(item["id"])}
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
                "wait" => @wait,
            })
            state = previous_state.update(hash)
            if hash_content
                (previous_state["content"] ||= []).concat(hash_content)
            end
            save_state_file(state)
        end

        def format(content)
            message_html = Site::HTML_HEADER.dup
            message_html << "<ul style='list-style-type: none;'>\n"
            content.each do |item|
                msg = "<li id='#{item["id"]}'>"
                if item["url"]
                    msg += "<a href='#{item["url"]}'>"
                end
                if item["img_src"]
                     msg += "<img style='width:100px' src='#{item["img_src"]}'/>"
                end
                if item["title"]
                    msg += "#{item["title"]}"
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
    end
end
