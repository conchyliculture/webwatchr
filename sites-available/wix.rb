#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Wix < Site::SimpleString
	require "json"

    def get_content()
        res = ""
        jsons = @parsed_content.css('link').select{|l| l.attr('rel')=="preload" and l.attr('href')=~/.json/}.map{|l| l['href']}
        jsons.each do |jurl|
            j = JSON.parse(Net::HTTP.get(URI.parse(jurl)))["data"]["document_data"]
            j.each do |k,v|
                if v["type"] =~/text/i
                    r = Nokogiri::HTML.parse(v["text"])
                    res += r.text+"\n"
                end
            end
        end
        return res
    end
end

#Wix.new(
#    url: "http://a.website/made.with/wix.com"
#    every: 2*60*60,
#    test: __FILE__== $0,
#).update
