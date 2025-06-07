require_relative "../webwatchr/site"

class Accor < Site::SimpleString
  require "mechanize"
  require "json"

  def command?(name)
    `which #{name}`
    $?.success?
  end

  def initialize(hotel_id:, start_date:, nights:, every: 60 * 60, comment: nil)
    @state_file_name = "last-accor-#{hotel_id}-#{start_date}-#{nights}_nights"
    @api_key = "l7xx5b9f4a053aaf43d8bc05bcc266dd8532"
    @client_id = "all.accor"

    unless command?('qjs')
      raise StandardError, 'you need to install quickjs first'
    end

    super(
      url: "https://all.accor.com/ssr/app/accor/rates/#{hotel_id}/index.en.shtml?compositions=1&dateIn=#{start_date}&nights=#{nights}&hideHotelDetails=false&hideWDR=false&destination=",
      every: every,
      comment: comment
    )
    @hotel_id = hotel_id
    @start_date = start_date
    @nights = nights
    unless @hotel_id.to_s =~ /^\d+$/
      raise Site::ParseError, "accor.rb needs a valid hotel ID such as '1234', not '#{@hotel_id}')"
    end
    unless @start_date =~ /^\d\d\d\d-\d\d-\d\d$/
      raise Site::ParseError, "accor.rb needs a valid start_date, in format YYYY-MM-DD, not '#{@start_date}')"
    end
    unless @nights.to_s =~ /^\d+$/
      raise Site::ParseError, "accor.rb needs a valid number of nights, not '#{@nights}')"
    end
  end

  def get_api(url)
    m = Mechanize.new()
    m.request_headers['apiKey'] = @api_key
    m.request_headers['clientId'] = @client_id
    m.request_headers['Accept'] = 'application/json'
    res = m.get(url)
    return res.body
  end

  def get_rooms(hotel_id, start_date, nights)
    res = get_api("https://api.accor.com/availability/v3/hotels/#{hotel_id}/rooms?fields=rooms.capacity,rooms.code,rooms.commercialOffers,rooms.offers,rooms.referenceOffers,rooms.roomClass&adults=1&childrenAges=&dateIn=#{start_date}&nights=#{nights}&pricing=true&pricingDetails=true&pricingFees=true&roomFamilies=&roomIndex=0")
    j = JSON.parse(res)
    return j
  end

  def get_hotel_data(hotel_id, start_date, nights)
    m = Mechanize.new()
    res = m.get("https://all.accor.com/ssr/app/accor/rates/#{hotel_id}/index.en.shtml?compositions=1&dateIn=#{start_date}&nights=#{nights}&hideHotelDetails=false&hideWDR=false&destination=").body
    js = res.scan(/(__NUXT__.*\)\);)<\/script>/)[0][0]
    io = IO.popen(['qjs', '-e', "#{js}print(JSON.stringify(__NUXT__))"])
    data = JSON.parse(io.read)["data"][1]

    res = {}
    data['productAccommodations']['accommodations'].each do |a|
      id = a['id']
      res[id] = {
        'name' => a['label'],
        'description' => a['description']
      }
    end
    return res
  end

  def pull_things
    data = get_hotel_data(@hotel_id, @start_date, @nights)
    rooms = get_rooms(@hotel_id, @start_date, @nights)["rooms"]
    res = ["<ul>"]
    rooms.each do |r|
      d = data[r['code']]
      res << "<li>#{d['name']}<ul>"
      r['offers'].each do |o|
        price = o['pricing']['amount']['hotelKeeper']
        currency = o['pricing']['currency']
        code = o['code']
        #        link = "https://api.accor.com/availability/"+o['href']
        res << "<li>#{price} #{currency} code: #{code}</li>"
      end
      res << "</li>"
    end
    res << "</ul>"
    @html_content = res
  end

  def get_content
    return ResultObject.new(@html_content.join("\n"))
  end
end

#
# Get hotel code (ie: 1234) from the URL on the relevant Accor website
#
# Example:
#
# Accor.new(
#      start_date: "2024-07-18",
#      nights: 3,
#      hotel_id: "5011",
#  )
