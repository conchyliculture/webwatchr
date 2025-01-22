require_relative "../lib/site.rb"

class ChitChats < Site::SimpleString
    def initialize(track_id:, every:, comment:nil, test:false)
        super(
          url: "https://chitchats.com/tracking/#{track_id}",
          every: every,
          test: test,
          comment: comment,
        )
    end

    def get_content
      table = @parsed_content.css("div.tracking-history table")[0]
      res = ["<ul>"]
      table.css('tr').each do |tr|
        day = ""
        if tr.css('td.tracking-table__empty-heading').size == 2
          day = tr.css('td span')[0].text.strip
        else
          time = tr.css('td span')[0].text.strip
          thing = tr.css('td')[1].text.strip
          place = tr.css('td')[2].text.strip
          msg = "<li>#{day} #{time}: #{thing}"
          if place!=""
            msg << " (#{place})"
          end
          res << msg+"</li>"
        end
      end
      res << "</ul>"
      return res.join("\n")
    end

end

# Example:
# 
# ChitChats.new(
#     track_id: "10pokwhaos",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
