$: << File.dirname(__FILE__)

require "classe.rb"

class PostCH < Classe
    def get_content()
        res = []
        table = @parsed_content.css('table.events_view tr').map{|row| row.css("td").map{|r| r.text.strip}}.delete_if{|x| x.empty?}
        if table.size==0
            $stderr.puts "Please verify the PostCH tracking ID"
            return nil
        end
        table.each do |r|
            res << "#{r[0]} - #{r[1]} : #{r[3]}: #{r[2].split("\n")[-1].strip()}<br/>\n"
        end
        return res.join("")
    end
end

post_id="99.60.00000.00000000"
PostCH.new(url:  "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes=#{post_id}",
              every: 30*60, 
              test: __FILE__ == $0
          ).update

