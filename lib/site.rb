#!/usr/bin/ruby
# encoding: utf-8

require "digest/md5"
require "json"
require "logger"
require "net/http"
require "nokogiri"

class Site

    Site::HTML_HEADER="<!DOCTYPE html>\n<meta charset=\"utf-8\">\n"

    attr_accessor :state_file, :url, :wait
    def initialize(url:, every: 60*60, post_data: nil, test: false)
        @logger = $logger || Logger.new(STDOUT)
        @name = url
        @post_data = post_data
        @test = test
        @url = url
        @wait = every
        md5 = Digest::MD5.hexdigest(url)
        @state_file = ".lasts/last-#{md5}"
        if $CONF and $CONF["last_dir"]
            @state_file = File.join($CONF["last_dir"] || ".", "last-#{md5}")
        end
        @logger.debug "using #{@state_file} to store updates"
    end

    def fetch_url(url)
        html = ""
        uri = URI(url)
        if @post_data
            res = Net::HTTP.post_form(uri, @post_data).body
        else
            Net::HTTP.start(uri.host, uri.port) do |http|
                response = Net::HTTP.get_response(uri)
                html  = response.body
                if html and response["Content-Encoding"]
                    html = html.force_encoding(response["Content-Encoding"])
                end
            end
        end
        @logger.debug "Fetched #{url}"
        return html
    end

    def parse_noko(html)
        return Nokogiri::HTML(html)
    end

    def read_last()
        data = {
            "time" => -9999999999999,
            "content" => nil,
        }
        if File.exist?(@state_file)
            begin
                data = JSON.parse(File.read(@state_file))
            rescue JSON::ParserError
            end
        end
        return data
    end

    def save_last_file(stuff)
        data={
            "time" => Time.now.to_i,
            "url" => @url,
            "wait" => @wait,
            "content" => stuff,
        }
        File.open(@state_file,"w") do |f|
            f.write JSON.pretty_generate(data)
        end
    end

    def alert(new_stuff)
        @logger.debug "Alerting new stuff"
        $CONF["alert_proc"].call({content: to_html(new_stuff), name: @name})
    end

    def get_content()
        return @http_content
    end

    def should_check?(prev_time)
        return Time.now().to_i >= prev_time + @wait
    end

    def get_new(previous: nil)
        @content = get_content()
        return @content
    end

    def update()
        begin
            new_stuff = false
            prev = read_last()
            prev_content = prev["content"]
            if should_check?(prev["time"]) or @test
                @logger.info "Time to update" unless @test
                @http_content = fetch_url(@url)
                @parsed_content = parse_noko(@http_content)
                new_stuff = get_new(previous: prev_content)
                if new_stuff
                    if @test
                        puts "Would have sent an email with #{to_html(new_stuff)}"
                    else
                        alert(new_stuff)
                        save_last_file(new_stuff)
                    end
                else
                    if @test
                        puts "Nothing new"
                    end
                    @logger.info "Nothing new"
                end
            else
                @logger.info "Too soon to update"
            end
        rescue Exception => e
            $stderr.puts "#{self} Failed on #{@url}"
            $stderr.puts e.class
            $stderr.puts e.message
            $stderr.puts e.backtrace
            $stderr.puts "state_file : #{@state_file}"
        end
    end

    def to_html(content)
        message_html = Site::HTML_HEADER.dup
        message_html += @content
        return message_html
    end

    class Site::SimpleString < Site

        def get_new(previous: nil)
            new_stuff = nil
            @content = get_content()
            if @content != previous
                new_stuff = @content
            end
            return new_stuff
        end

        def to_html(content)
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

        def get_new(previous: nil)
            new_stuff = nil
            get_content()
            if previous
                previous_ids = previous.map{|h| h["id"]}
                new_stuff = @content.delete_if{|item| previous_ids.include?(item["id"])}
            else
                new_stuff = @content
            end
            if (!new_stuff) or  new_stuff.empty?
                return nil
            end
            return new_stuff
        end

        def save_last_file(stuff)
            data = {}
            if File.exist?(@state_file)
                data = JSON.parse(File.read(@state_file))
            end
            data["time"] = Time.now.to_i
            data["url"] = @url
            data["wait"] = @wait
            (data["content"] ||= []).concat(stuff)
            @logger.debug "Appending #{stuff.size} new items to #{@state_file}"
            File.open(@state_file,"w") do |f|
                f.write JSON.pretty_generate(data)
            end
        end

        def to_html(content)
            message_html = Site::HTML_HEADER.dup
            message_html << "<ul style=\"list-style-type: none;\">\n"
            content.each do |item|
                msg = "<li id='#{item["id"]}'>"
                if item["url"]
                    msg += "<a href='#{item["url"]}'>"
                end
                if item["img_src"]
                     msg += "<img style=\"width:100px\" src='#{item["img_src"]}'/>"
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
