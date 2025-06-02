require_relative "../lib/site"

require "net/http"
require "json"

class DHL < Site::SimpleString
  def initialize(track_id:, every: 60 * 60, api_key: nil, comment: nil)
    unless api_key
      raise Site::ParseError,
            'DHL requires an API key for fetching tracking information. Get one by registering for a free account at https://developer.dhl.com/'
    end

    @api_key = api_key
    @track_id = track_id
    super(
      url: "https://www.dhl.com/ch-en/home/tracking/tracking-express.html?submit=1&tracking-id=#{track_id}",
      every: every,
      comment: comment
    )
  end

  def pull_things
    uri = URI("https://api-eu.dhl.com//track/shipments?trackingNumber=#{@track_id}")
    req = Net::HTTP::Get.new(uri)
    req['DHL-API-Key'] = @api_key
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.use_ssl = true
      http.request(req)
    end
    @parsed_content = JSON.parse(res.body)
  end

  def get_content
    case @parsed_content["status"]
    when 401
      raise StandardError, "Error pulling data from DHL API: #{@parsed_content['status']} #{@parsed_content['detail']}"
    when 404
      return @parsed_content['detail']
    when 429
      raise Site::ParseError, "DHL is rate limiting us"
    when 500
      raise Site::ParseError, "DHL is down lol #{@parsed_content['detail']}"
    end
    shipment = @parsed_content["shipments"][0]
    res = []
    if @comment
      res << "Update for #{@comment}"
    end
    if shipment["estimatedTimeOfDeliveryRemark"]
      res << "Estimated time of delivery: "
      res << "#{shipment['estimatedTimeOfDelivery']} #{shipment['estimatedTimeOfDeliveryRemark']}"
    end

    res << "<ul>"
    @parsed_content["shipments"][0]["events"].each do |e|
      res << "<li>#{e['timestamp']}: #{e['description']} (#{e.dig('location', 'address', 'addressLocality')})</li>"
    end
    res << "</ul>"

    return ResultObject.new(res.sort.reverse.join("\n"))
  end
end

# example:
# DHL.new(
#     track_id: "1234567890",
#     api_key: "j6VSqAm4RmlljLKJLajlP")
