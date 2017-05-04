#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostSG < Site::SimpleString

    # Here we want to do check only part of the DOM.
    #   @http_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@http_content)
    #
    def get_content()
        res = []
        l = @parsed_content.css("div.tracking-info-header div")
        if l.size == 0
            raise Site::ParseError.new("Please verify the PostSG tracking ID")
        end
        status = ""
        l.each do |l|
            case l.attr("class")
            when "tracking-status-text"
                status = l.text.strip()
            when "tracking-no-text"
                date = l.text.strip()
                if date =~ /\d\d\/\d\d\/\d\d\d\d/
                    res << "#{date} : #{status}"
                end
            end
        end

        if not res.empty?
            return res.join("<br/>\n\n\n\n")
        end
        return nil
    end

end

trackingnb = "RB000000000SG"
PostSG.new(
    url: "http://www.singpost.com/track-items",
    post_data: {
        "track_number" => trackingnb,
        "captoken" => "",
        "op" => "Check item status"
    },
    every: 60*60,
   test: __FILE__ == $0
).update

