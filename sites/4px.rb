#!/usr/bin/ruby

require_relative "../lib/site.rb"
require "json"

class Post4PX < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://track.4px.com/track/v2/front/listTrackV2",
          every: every,
          test: test,
          comment: comment,
          post_json: {"queryCodes" => [track_id]}
        )
        @track_id = track_id
    end

    def parse_content(html)
      return JSON.parse(html)
    end

    def get_content()
        res = []
        @parsed_content["data"][0]["tracks"].each do |t|
          m = "#{t['tkDateStr']}: #{t['tkDesc']}"
          if not t['tkLocation'].empty?
            m << " ("+t['tkLocation']+")"
          end
          res << "<li>"+m+"</li>" 
        end
        if res.size() > 0
          res = ["<ul>"] << res << ["</ul>"]
          return res.join("\n")
        end
        return nil
    end
end

# Example:
#
# Post4PX.new(
#    track_id: "4PX0000000000000CN",
#     every: 30*60,
#    test: __FILE__ == $0
#).update
