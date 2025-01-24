#!/usr/bin/ruby

require_relative "../lib/site"
require "json"

class Post4PX < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, comment: nil)
    super(
      url: "https://track.4px.com/track/v2/front/listTrackV2",
      every: every,
      comment: comment,
      post_json: { "queryCodes" => [track_id] }
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
      unless t['tkLocation'].empty?
        m << " (#{t['tkLocation']})"
      end
      res << "<li>#{m}</li>"
    end
    if res.empty?
      res = ["<ul>"] << res << ["</ul>"]
      return res.join("\n")
    end
    return nil
  end
end

# Example:
#
# Post4PX.new(track_id: "4PX0000000000000CN")
