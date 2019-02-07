#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class PostSG < Site::SimpleString

    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url: "http://www.singpost.com/track-items",
            post_data: {
                "track_number" => track_id,
                "captoken" => "",
                "op" => "Check item status"
            },
            every: every,
            test: test,
            comment: comment,
        )
    end

    # Here we want to do check only part of the DOM.
    #   @html_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@html_content)
    #
    def get_content()
        res = []
        l = @parsed_content.css("div.tracking-info-header div")
        if l.size == 0
            raise Site::ParseError.new("Please verify the PostSG tracking ID")
        end
        status = ""
        l.each do |ll|
            case ll.attr("class")
            when "tracking-status-text"
                status = ll.text.strip()
            when "tracking-no-text"
                date = ll.text.strip()
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

PostSG.new(
    track_id: "RB000000000SG",
    every: 60*60,
    test: __FILE__ == $0
).update
