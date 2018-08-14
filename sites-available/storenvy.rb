#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Storenvy < Site::SimpleString

    def is_closed?
        maintenance = @parsed_content.css("div#maintenance")
        return ! maintenance.empty?
    end

    def get_content()
        if is_closed?()
            return "Store is closed"
        else
            return "<a href='#{@url}'>Store is open</a>"
        end
    end
end


[].each do |store_name|
    Storenvy.new(
        url: "http://storenvy.com/#{store_name}",
        every: 12 * 60 * 60,
        comment: "#{store_name} Storenvy",
        test: __FILE__ == $0
    ).update
end
