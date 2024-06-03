require_relative "../lib/site.rb"

class ZenChef < Site::SimpleString
    def initialize(restaurant_id:, date_begin:,date_end:, every:, messages:nil, comment:nil, test:false)
      raise Exception.new("Please provide date_begin with YYYY-MM-DD format") unless date_begin=~/^\d\d\d\d-\d\d-\d\d$/
      raise Exception.new("Please provide date_end with YYYY-MM-DD format") unless date_begin=~/^\d\d\d\d-\d\d-\d\d$/
      raise Exception.new("Please provide a proper restaurant_id") unless restaurant_id=~/^\d+$/
        super(
            url: "https://bookings-middleware.zenchef.com/getAvailabilitiesSummary?restaurantId=#{restaurant_id}&date_begin=#{date_begin}&date_end=#{date_end}",
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content
      res = ""
      JSON.parse(@html_content).select{|d| not d['shifts'].empty? and not d['shifts'].map{|a| a['possible_guests']}.flatten.empty?}.each do |p|
        res << "Possible date: #{p['date']}. "
        p['shifts'].each do |shift|
          res << "#{shift['name']}: Possible guests: #{shift['possible_guests']}\n"
        end
      end
      return res
    end
end

# Example:
#
# ZenChef.new(
#     restaurant_id: "123456",
#     date_begin: "2024-06-01",
#     date_end: "2024-06-30",
#     comment: "My favorite resto",
#     every: 30*60,
#     test: __FILE__ == $0
# ).update
