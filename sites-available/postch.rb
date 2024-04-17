#!/usr/bin/ruby

require_relative "../lib/site.rb"

class PostCH < Site::SimpleString

    attr_accessor :messages
    def initialize(track_id:, every:, messages:nil, comment:nil, test:false)
        super(
            url: "https://www.post.ch/api/TrackAndTrace/Get?sc_lang=en&id=#{track_id}",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
        @events = []
    end

    def pull_things()
        # First we need an anonymous userId
        json_body = Net::HTTP.get(URI.parse(@url))
        @parsed_content = JSON.parse(json_body)
    end

    def get_html_content()
      res = []
      res << Site::HTML_HEADER
      res << "<ul>"
      @events.each do|event|
        res << "<li>#{@event}</li>"
      end
      res += @events
      res << "</ul>"
      return res.join("\n")
    end

    def get_content()
      if @parsed_content["ok"] == "true"
        @parsed_content["events"].each do |event|
          msg = "#{event['date']} #{event['time']}: #{event['description']}"
          if event['city'] != ""
            msg += " (#{event['city']} #{event['zip']})"
          end
          @events << msg
        end
      else
        return "No result from PostCH API for #{@track_id}"
      end

      return @events.join("\n")
    end
end

# Example:
#
# PostCH.new(
#     track_id: "99.60.00000.00000000",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
