require_relative "../webwatchr/site"

require "net/http"
require "json"

class DHL < Site::SimpleString
  def track_id(track_id)
    @track_id = track_id
    @url = "https://api-eu.dhl.com/track/shipments?trackingNumber=#{track_id}"
    self
  end

  def api_key(api_key)
    @api_key = api_key
    self
  end

  def pull_things
    raise Site::ParseError, "No track_id set" unless @track_id
    raise Site::ParseError, "No api_key set. Get one free at https://developer.dhl.com/" unless @api_key

    uri = URI("https://api-eu.dhl.com/track/shipments?trackingNumber=#{@track_id}")
    req = Net::HTTP::Get.new(uri)
    req["DHL-API-Key"] = @api_key
    req["Accept"]      = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    @parsed_json = JSON.parse(response.body)

    case response.code
    when "401"
      raise Site::ParseError, "DHL API key rejected: #{@parsed_json['detail']}"
    when "429"
      raise Site::ParseError, "DHL API rate limit exceeded"
    when "500"
      raise Site::ParseError, "DHL API server error: #{@parsed_json['detail']}"
    end
  end

  def extract_content
    shipments = @parsed_json["shipments"]
    if shipments.nil? || shipments.empty?
      return Site::SimpleString::ResultObject.new(
        @parsed_json["detail"] || "Shipment #{@track_id} not found"
      )
    end

    shipment = shipments[0]
    res = Site::SimpleString::ListResult.new

    status = shipment.dig("status", "description")
    res << "Status: #{status}" if status

    etd    = shipment["estimatedTimeOfDelivery"]
    remark = shipment["estimatedTimeOfDeliveryRemark"]
    res << "Estimated delivery: #{[etd, remark].compact.join(' ')}" if etd

    (shipment["events"] || []).each do |event|
      ts       = event["timestamp"]
      desc     = event["description"]
      locality = event.dig("location", "address", "addressLocality")
      line = "#{ts}: #{desc}"
      line += " (#{locality})" if locality
      res << line
    end

    res
  end
end
