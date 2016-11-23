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
        uri = URI(url)
        return Net::HTTP.get(uri)
    end

    def parse_noko(html)
        return Nokogiri::HTML(html)
    end

    def initialize(url:, every:, test: false)
        @url=url
        @http_content=fetch_url(@url)
        @parsed_content=parse_noko(@http_content)
        @wait = every
        @name = url
        md5=Digest::MD5.hexdigest(url)
        @last_file=".lasts/last-#{md5}"
        @test=test
        update()
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
        send_mail(dest_email: $CONF["dest_email"],content: new_stuff)
    end

    def get_content()
        return @http_content
    end

    def update()
        new_stuff = false
        prev = read_last()
        prev_content = prev["content"]
        if (Time.now().to_i >= prev["time"] + @wait) or @test # Don't follow time limit if we're testing
            puts "It's time to update" if $VERBOSE
            @content = get_content()
            case @content
            when String
                if @content != prev_content
                    new_stuff = @content
                end
            when Array
                if prev_content
                    if ! (@content - prev_content).empty?
                        new_stuff = (@content - prev_content)
                    end
                else
                    new_stuff = @content
                end
            end
            if new_stuff
                if @test
                    # Just show result, don't send email or upsate @last file
                    puts "Would have sent an email with #{to_html(new_stuff)}"
                else
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

    def send_mail(dest_email: nil, content: nil, from: $from, subject: nil)
        unless subject
            subject= "[Webwatchr] Site #{@name} updated"
        end
        @msg="Site #{@name} updated"
        if content
            @msg+=" with content:\n"+to_html(content)
        end

        msgstr = <<END_OF_MESSAGE
From: #{from}
To: #{dest_email}
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
Subject: #{subject}

#{@msg}
END_OF_MESSAGE

        Net::SMTP.start($CONF["smtp_server"], $CONF["smtp_port"]) do |smtp|
            smtp.send_message(msgstr, from, dest)
            puts "mail sent lol"
        end
    end
end

# Example call.
#
# This will fetch the entire google.com page, every 10*60 seconds, and mail
# the full HTML everytime it changes (probably, everytime)
#
# Every 'every' seconds, we pull the html page and extracte "content".
# using the get_content method. Just overload the method in your class
# to your usage. It can either return a String or an Array.
# This 'content' will be compared with the previous stored one, and a mail
# will be sent with the new String (if get_content() returns a String),
# or the new items in the Array (if get_content() returns an Array).
#
# c = Classe.new(url: "https://www.google.com", 
#                every: 10*60 # Check every 10 minutes,
#                test: __FILE__ == $0  # This is so you can run ruby classe.rb to check your code
#                )
