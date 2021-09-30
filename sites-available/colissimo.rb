#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"
require "mechanize"
require "json"

class Colissimo < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
            url:  "https://api.laposte.fr/ssu/v1/suivi-unifie/idship/#{@track_id}?lang=en_GB",
            every: every,
            test: test,
            comment: comment,
        )
        @track_id = track_id
    end

    def pull_things()
      mechanize = Mechanize.new
      # Get a cookie
      mechanize.get("https://www.laposte.fr/outils/track-a-parcel")
      mechanize.request_headers["Accept"]='application/json'
      j = mechanize.get(
        "https://api.laposte.fr/ssu/v1/suivi-unifie/idship/#{@track_id}?lang=en_GB"
      )
      @html_content = j.body
      @parsed_content = JSON.parse(@html_content)
    end

    def get_content()
        res = []
        @parsed_content['shipment']['event'].each do |e|
          res << e['date']+": "+e['label']
        end
        return res.join("\n")
    end
end

# Example:
# Colissimo.new(
#     track_id: "CB0129291929FR",
#     every: 2*60*60,
#     test: __FILE__ == $0
# ).update
