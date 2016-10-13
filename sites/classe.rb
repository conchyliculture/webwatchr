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

    def fetch_url(url)
        uri = URI(url)
        return Net::HTTP.get(uri)
    end

    def parse_noko(html)
        return Nokogiri::HTML(html)
    end

    def initialize(url:, every:, proque: nil, test: false)
        @url=url
        @http_content=fetch_url(@url)
        @parsed_content=parse_noko(@http_content)
        @wait = every
        @proque = proque
        @name = url
        md5=Digest::MD5.hexdigest(url)
        @last_file=".lasts/last-#{md5}"
        @test=test
        if @test
            puts get_content()
        else
            update()
        end
    end

    def read_last()
        time = 9999999999999
        md5=nil
        if File.exist?( @last_file)
            time,md5 = File.open(@last_file,&:readline).strip().split(" ")
        end
        return {"time"=> time.to_i , "md5" => md5}
    end

    def update_last(md5)
        f=File.open(@last_file,"w")
        f.write("#{Time.now.to_i} #{md5}")
        f.write("\n")
        f.write("\n")
        f.write("\n")
        f.write("\n")
        f.write(@content)
        f.close()
    end

    def calc_md5_from_content(s)
        md5 =  Digest::MD5.hexdigest(s)
        return md5
    end

    def alert()
        puts "Sending a mail!" if $VERBOSE
        send_mail($CONF["dest_email"])
    end

    def get_content()
        if @proque
            return instance_eval &@proque
        else
            return @http_content
        end
    end

    def update()
        res= read_last()
        if res["md5"]
            if @test or (Time.now().to_i >= res["time"] + @wait)
                puts "It's time to update" if $VERBOSE
                @content=get_content()
                md5=calc_md5_from_content(@content)
                if md5!=res["md5"]
                    if @test 
                        puts "Would have sent an email with #{@content}"
                    else
                        alert()
                        update_last(md5)
                    end
                end
            end
        else
            @content=get_content()
            md5=calc_md5_from_content(@content)
            update_last(md5)
        end
    end

    def send_mail(dest,from=$from,subject=nil)
        unless subject
            subject= "[Webwatchr] Site #{@name} updated"
        end
        unless @msg
            @msg="Site #{@name} updated"
            if @content
                @msg+=" with content:\n"+@content.to_s
            end
        end

        msgstr = <<END_OF_MESSAGE
From: #{from}
To: #{dest}
MIME-Version: 1.0
Content-type: text/html
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
# By default this will make a MD5 on the whole HTML code and alert you
# only when the MD5 changes. This is trivial and might not work, you 
# may want to only check the MD5 on part of the HTML, this is explained later.
#
#
# c = Classe.new(url: "https://www.google.com", 
#                every: 10*60 # Check every 10 minutes,
#                test: __FILE__ == $0  # This is so you can run ruby classe.rb to check your code
#                )
