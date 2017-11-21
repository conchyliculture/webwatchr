#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class DHL < Site::SimpleString
    require "date"
    require "json"

    # Here we want to do check only part of the DOM.
    #   @html_content contains the HTML page as String
    #   @parsed_content contains the result of Nokogiri.parse(@html_content)
    #
    def get_content()
        res = ""
        j = JSON.parse(@html_content)
        unless j['results']
            raise Site::ParseError("Please verify the DHL tracking ID #{@url}")
        end
        j['results'][0]["checkpoints"].each do |l|
            descr = l['description']
            time = DateTime.strptime("#{l['date']} #{l['time']}","%A, %B %d, %Y %H:%M")
            location = l['location']
            res << "#{time} : #{descr} (#{location})<br/>\n"
        end
        return res
    end

end

trackingnb="0000000000"
DHL.new(
    url:  "http://www.dhl.com/shipmentTracking?AWB=#{trackingnb}",
    every: 60*60,
   test: __FILE__ == $0
).update

