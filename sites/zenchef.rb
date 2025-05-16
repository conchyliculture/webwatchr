require_relative "../lib/site"

class ZenChef < Site::SimpleString
  def initialize(restaurant_id:, date_begin:, date_end:, every: 60 * 60, comment: nil)
    raise StandardError, "Please provide date_begin with YYYY-MM-DD format" unless date_begin =~ /^\d\d\d\d-\d\d-\d\d$/
    raise StandardError, "Please provide date_end with YYYY-MM-DD format" unless date_begin =~ /^\d\d\d\d-\d\d-\d\d$/
    raise StandardError, "Please provide a proper restaurant_id" unless restaurant_id =~ /^\d+$/

    super(
      url: "https://bookings-middleware.zenchef.com/getAvailabilitiesSummary?restaurantId=#{restaurant_id}&date_begin=#{date_begin}&date_end=#{date_end}",
      every: every,
      comment: comment,
      )
  end

  def get_content
    res = ""
    JSON.parse(@html_content).select { |d| not d['shifts'].empty? and not d['shifts'].map { |a| a['possible_guests'] }.flatten.empty? }.each do |p|
      res << "Possible date: #{p['date']}. "
      p['shifts'].each do |shift|
        res << "#{shift['name']}: Possible guests: #{shift['possible_guests']}\n"
      end
    end
    return ResultObject.new(res)
  end
end

# Example:
#
# ZenChef.new(
#     restaurant_id: "123456",
#     date_begin: "2024-06-01",
#     date_end: "2024-06-30",
#     comment: "My favorite resto",
#     )
