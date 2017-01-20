#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class UPS < Site::SimpleString
    require "date"
    require "net/http"
    require "json"

    def get_coords(search)
        url = "http://maps.googleapis.com/maps/api/geocode/json?address=#{search}&sensor=false"
        j = JSON.parse(Net::HTTP.get(URI.parse(url.gsub(' ','+'))))
        if j["status"]=="OK"
            # Hopeing first result is good
            return j["results"][0]["geometry"]["location"]
        end
        return nil
    end

    def make_static_url(places)
        colors=%w{black brown green purple yellow blue gray orange red white}

        url = "http://maps.google.com/maps/api/staticmap?"
        url << "size=1024x768"
        url << "&zoom=3"
        url << "&path=color:0xff0000ff|weight:5"
        places.reverse.each do |p|
            url << "|#{p}"
        end

        i=0
        places.reverse.each do |p|
            url << "&markers=color:#{colors[i % colors.size()]}|label:#{i}|#{p}"
            i+=1
        end

        url << "&sensor=false"
        return url
    end

    def get_content()
        res = ""
        table = @parsed_content.css("table.dataTable tr")
        if table.size==0
            $stderr.puts "Please verify the UPS tracking ID #{@url}"
            @logger.error "Please verify the UPS tracking ID #{@url}"
            return nil
        end
        headers = table[0].css("th").map{|x| x.text}
        places=[]
        prev_place = ""
        table[1..-1].each do |tr|
            row = tr.css("td").map{|x| x.text.strip().gsub(/[\r\n\t]/,"").gsub(/  +/," ")}
            time = DateTime.strptime("#{row[1]} #{row[2]}","%m/%d/%Y %l:%M %p")
            place = row[0].gsub(" ","+")
            if place != "" and (place != prev_place)
                places << place
                prev_place = place
                row[0] = " (#{row[0]})"
            end
            res << "#{time} : #{row[3]}#{row[0]}<br/>\n"
        end
        url = make_static_url(places)
        res << "\n<br/><a href='#{url}'><img src='#{url}' alt='pic'>pic</a>\n"
        return res
    end
end

ups_id="AAAAAAAAAAAAAAAAAA"
UPS.new(
    url:  "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=#{ups_id}",
    every: 30*60,
    test: __FILE__ == $0
).update

