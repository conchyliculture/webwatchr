require_relative "../webwatchr/site"

require "net/http"
require "json"

# DHL Shipment Tracking via the official DHL Unified Tracking API.
# Get a free API key at https://developer.dhl.com/
#
# When a parcel crosses into a new country DHL assigns a domestic consignment ID
# (found in details.references). If that leg hides shipper/consignee cities behind
# a postcode check, supply postal_code to unlock them.
#
# Example:
#
#   update DHL do
#     track_id    "CB123546789DE"
#     api_key     "your_dhl_api_key"
#     postal_code "12345"           # optional — unlocks address details on a Foreign leg
#   end

class DHL < Site::SimpleString
  def initialize
    super()
    @update_interval = 6 * 60 * 60
  end

  def track_id(track_id)
    @track_id = track_id
    @url = "https://api-eu.dhl.com/track/shipments?trackingNumber=#{track_id}"
    self
  end

  def api_key(api_key)
    @api_key = api_key
    self
  end

  def postal_code(postal_code)
    @postal_code = postal_code
    self
  end

  def pull_things
    raise Site::ParseError, "No track_id set" unless @track_id
    raise Site::ParseError, "No api_key set — get one free at https://developer.dhl.com/" unless @api_key

    @shipments = []
    fetch_shipment(@track_id)

    # Follow domestic-consignment-id references into destination-country legs
    refs = @shipments.first&.dig("details", "references") || []
    refs.each do |ref|
      next unless ref["type"] == "domestic-consignment-id"

      fetch_shipment(ref["number"], postal_code: @postal_code)
    end
  end

  def extract_content
    if @shipments.empty?
      return Site::SimpleString::ResultObject.new(
        @parsed_error || "Shipment #{@track_id} not found"
      )
    end

    res = Site::SimpleString::ListResult.new

    # Current status + ETA from the most recent leg
    last = @shipments.last
    status = last.dig("status", "description")
    res << "Status: #{status}" if status

    etd    = last["estimatedTimeOfDelivery"]
    remark = last["estimatedTimeOfDeliveryRemark"]
    res << "Estimated delivery: #{[etd, remark].compact.join(' ')}" if etd

    # All events across all legs, newest first
    all_events = @shipments.flat_map { |s| s["events"] || [] }
    all_events.sort_by { |e| e["timestamp"] }.reverse.each do |event|
      ts       = event["timestamp"]
      desc     = event["description"]
      # Strip inline HTML links that DHL sometimes embeds in descriptions
      desc     = desc.gsub(/<[^>]+>/, "").squeeze(" ").strip if desc
      locality = event.dig("location", "address", "addressLocality")
      line = "#{ts}: #{desc}"
      line += " (#{locality})" if locality
      res << line
    end

    res
  end

  private

  def fetch_shipment(tracking_number, postal_code: nil)
    params = { trackingNumber: tracking_number }
    params[:postalCode] = postal_code if postal_code

    uri = URI("https://api-eu.dhl.com/track/shipments")
    uri.query = URI.encode_www_form(params)

    req = Net::HTTP::Get.new(uri)
    req["DHL-API-Key"] = @api_key
    req["Accept"]      = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    body = JSON.parse(response.body)

    case response.code
    when "401"
      raise Site::ParseError, "DHL API key rejected: #{body['detail']}"
    when "429"
      raise Site::ParseError, "DHL API rate limit exceeded"
    when "500"
      raise Site::ParseError, "DHL API server error: #{body['detail']}"
    end

    if body["shipments"]
      @shipments.concat(body["shipments"])
    else
      @parsed_error = body["detail"]
    end
  end
end
