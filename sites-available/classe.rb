#!/usr/bin/ruby

class Classe
    
    # This class provides basically everything you need.
    #
    # To make a new site to watch, just make a new ruby file next to it
    # and extend Classe, like I do in dhl.rb
    #
    # THen in the file, just initialize a new object with the correct URL:
    # class Lol < Classe
    # end
    #
    # d = Lol.new()
    
    require "net/http"
    require "net/smtp"
    require "digest/md5"
    require "nokogiri"
    require "json"

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

    attr_accessor :last_file
    def initialize(url:, every:, post_data: nil, test: false)
        @url=url
        @post_data = post_data
        @http_content=fetch_url(@url)
        @parsed_content=parse_noko(@http_content)
        @wait = every
        @name = url
        md5=Digest::MD5.hexdigest(url)
        @last_file=File.join($CONF["last_dir"],".lasts/last-#{md5}")
        @test=test
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

    def update()
        new_stuff = false
        prev = read_last()
        prev_content = prev["content"]
        if should_check?(prev["time"]) or @test # Don't follow time limit if we're testing

            puts "It's time to update" if $VERBOSE
            @content = get_content()
            case @content
            when String
                case prev_content
                when String
                    if @content != prev_content
                        new_stuff = @content
                    end
                when Array
                    new_stuff = @content
                when nil
                    new_stuff = @content
                end
            when Array
                # Clean up eventual Nokogiri objects
                @content.map{|x| x.update(x){ |k,v| v.to_s}}
                case prev_content
                when String
                    new_stuff = @content
                when Array
                    if ! (@content - prev_content).empty?
                        new_stuff = (@content - prev_content)
                    end
                when nil
                    new_stuff = @content
                end
            end
            if @test
                puts (new_stuff ? "Would have sent an email with #{to_html(new_stuff)}" : "Nothing new\n#{to_html(new_stuff)}")
            else
                if new_stuff
                    alert(new_stuff)
                    update_last()
                end
            end
        end
    end

    def to_html(content)
        message_html = ""
        case content
        when String
            message_html = content
        when Array
            message_html = <<EOM
<!DOCTYPE html>
<meta charset="utf-8">
<ul style="list-style-type: none;">
EOM
            content.each do |item|
                if item["img_src"]
                    message_html +="<li><a href='#{item["href"]}'><img style=\"width:100px\" src='#{item["img_src"]}'>#{item["name"]} </a></li>\n"
                else
                    message_html +="<li><a href='#{item["href"]}'>#{item["name"]} </a></li>\n"
                end
            end
            message_html += "\n</ul>"
        end
        return message_html
    end

end
