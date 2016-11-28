$: << File.dirname(__FILE__)

require "classe.rb"
require "date"
require "pp"

class UPS < Classe
    def get_content()
        res = ""
        table = @parsed_content.css("table.dataTable tr")
        headers = table[0].css("th").map{|x| x.text}
        table[1..-1].each do |tr|
            row = tr.css("td").map{|x| x.text.strip().gsub(/[\r\n\t]/,'').gsub(/  +/,' ')}
            time = DateTime.strptime("#{row[1]} #{row[2]}","%m/%d/%Y %l:%M %p")
            if row[0] != ""
                row[0] = " (#{row[0]})"
            end
            res << "#{time} : #{row[3]}#{row[0]}\n"
        end
        return res
    end
end


$UPS_ID="AAAAAAAAAAAAAAAAAAAAAA"
UPS.new(url:  "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=#{$UPS_ID}",
              every: 30*60, 
              test: __FILE__ == $0
             )

