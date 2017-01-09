#!/usr/bin/ruby
# encoding: utf-8

require "digest/md5"
require "json"
require "net/http"
require "nokogiri"

class Site

    Site::HTML_HEADER="<!DOCTYPE html>\n<meta charset=\"utf-8\">\n"

    attr_accessor :last_file, :url, :wait
    def initialize(url:, every: 60*60, post_data: nil, test: false)
        @url = url
        @post_data = post_data
        @http_content = fetch_url(@url)
        @parsed_content = parse_noko(@http_content)
        @wait = every
        @name = url
        md5 = Digest::MD5.hexdigest(url)
        @last_file = ".lasts/last-#{md5}"
        if $CONF
            @last_file = File.join($CONF["last_dir"] || ".", "last-#{md5}")
        end
        @test=test
    end

    def fetch_url(url)
        res = ""
        uri = URI(url)
        if @post_data
            res= Net::HTTP.post_form(uri, @post_data).body
        else
            Net::HTTP.start(uri.host, uri.port) do |http|
                response = Net::HTTP.get_response(uri)
                res  = response.body
                if res
                    if response["Content-Encoding"]
                        res = res.force_encoding(response["Content-Encoding"])
                    end
                end
            end
        end
        res
    end

    def parse_noko(html)
        return Nokogiri::HTML(html)
    end

    def read_last()
        data={
            "time" => -9999999999999,
            "content" => nil,
        }
        if File.exist?(@last_file)
            begin
                data = JSON.parse(File.read(@last_file))
            rescue JSON::ParserError
            end
        end
        return data
    end

    def update_last()
        data={
            "time" => Time.now.to_i,
            "url" => @url,
            "wait" => @wait,
            "content" => @content,
        }
        File.open(@last_file,"w") do |f|
            f.write JSON.pretty_generate(data)
        end
    end

    def alert(new_stuff)
        puts "Sending a mail!" if $VERBOSE
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
        new_stuff = false
        prev = read_last()
        prev_content = prev["content"]
        if should_check?(prev["time"]) or @test
            new_stuff = get_new(previous: prev_content)
            if new_stuff
                if @test
                    puts "Would have sent an email with #{to_html(new_stuff)}"
                else
                    alert(new_stuff)
                    update_last()
                end
            else
                if @test
                    puts "Nothing new"
                end
            end
        end
    end

    def to_html(content)
        message_html = Site::HTML_HEADER.dup
        message_html += @content
        return message_html
    end

    class Site::String < Site

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
        def get_new(previous: nil)
            new_stuff = nil
            @content = get_content()
            new_stuff = @content
            if previous and (! (@content - previous).empty?)
                new_stuff = (@content - previous)
            end
            return new_stuff
        end

        def to_html(content)
            message_html = Site::HTML_HEADER.dup
            message_html << "<ul style=\"list-style-type: none;\">\n"
            content.each do |item|
                if item["img_src"]
                    message_html +="<li><a href='#{item["href"]}'><img style=\"width:100px\" src='#{item["img_src"]}'>#{item["name"]} </a></li>\n"
                else
                    message_html +="<li><a href='#{item["href"]}'>#{item["name"]} </a></li>\n"
                end
            end
            message_html += "\n</ul>"
            return message_html
        end
    end
end
