#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class Hilton < Site::SimpleString
  require "mechanize"
  require "json"

  def initialize(hotel_code:, start_date: , end_date: ,device_id:, app_id:, every:, comment:nil, test:false, group_code:nil)
    @state_file_name = "last-hilton-#{hotel_code}-#{start_date}-#{end_date}"
    super(
      url: "https://m.hilton.io/graphql/customer?type=ShopPropAvail&operationName=hotel_shopPropAvail&origin=ChooseRoomQBDataModel&pod=android",
      every: every,
      test: test,
      comment: comment
    )
    @mechanize = Mechanize.new()
    @bearer = nil
    @app_id = app_id
    @device_id = device_id
    @hotel_code = hotel_code.upcase
    @group_code = group_code
    raise Exception.new("Invalid app_id:'#{app_id}'. hilton.rb needs an app_id (ie: '01892712-1281-0192-0192-118201928102')") if not @app_id=~/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    raise Exception.new("Invalid device_id: '#{device_id}'. hilton.rb needs a device_id (ie: '19acb812dfe18cb1')") if not device_id=~/^[0-9a-f]{16}$/
    raise Exception.new("hilton.rb needs a hotel_code (ie: 'AOSLWKA')") if not @hotel_code=~/^[A-Z]{7}$/
    begin
      @start_date = Date.parse(start_date)
    rescue
      raise Exception.new("hilton.rb needs a valid start_date, not '#{start_date}')")
    end
    begin
      @end_date = Date.parse(end_date)
    rescue
      raise Exception.new("hilton.rb needs a valid end_date, not '#{end_date}')")
    end
    @base_headers = {
      "content-type" => "application/json; charset=UTF-8",
      "User-Agent" => "HHonors/2024.2.20 Dalvik/2.1.0 (Linux; U; Android 10; Android SDK built for x86_64 Build/QP1A.190711.019)",
      "x-hilton-upsell" => "true",
      "x-emb-path" => "/graphql/customer/ShopMultiPropAvailQuery",
      "deviceid" => device_id,
    }
  end

  def get_email_url()
    h = @hotel_code.downcase
    start = @start_date.strftime('%Y-%m-%d')
    stop = @end_date.strftime('%Y-%m-%d')
    url = "https://www.hilton.com/en/book/reservation/rooms/?ctyhocn=#{h}&arrivalDate=#{start}&departureDate=#{stop}&room1NumAdults=1"
    if @group_code
      url += "&groupCode=#{@group_code.upcase}"
    end
  end

  def _get_bearer
    url = "https://m.hilton.io/dx-customer/auth/applications/token"
    res = @mechanize.post(url, {"app_id": @app_id}.to_json, @base_headers)
    bearer = JSON.parse(res.body)["access_token"]
    @bearer = bearer
  end

  def pull_things()
    bearer = @bearer || _get_bearer()
    data = {
      "query" =>
        "query hotel_shopPropAvail($language: String!, $ctyhocn: String!, $guestId: BigInt, $input: ShopPropAvailQueryInput!) { hotel(ctyhocn: $ctyhocn, language: $language) { shopAvail(guestId: $guestId, input: $input) { roomTypes { roomTypeName roomTypeDesc roomOccupancy roomRates { __typename ...RoomAvailabilityRateFragment } } } } } fragment RoomAvailabilityRateFragment on ShopRoomTypeRate { rateAmountFmt(decimal: 0, strategy: trunc) rateAmount ratePlan { ratePlanName ratePlanDesc currencyCode  } }",
      "variables" => {
        "ctyhocn" => @hotel_code,
        "guestId"=>"0",
        "input"=> {
          "arrivalDate"=> @start_date.strftime('%Y-%m-%d'),
          "departureDate"=> @end_date.strftime('%Y-%m-%d'),
          "numAdults"=>1,
          "numRooms"=>1,
        },
        "language"=>"en",
        "operationName"=>"hotel_shopPropAvail"
      },
    }
    if @group_code
      data["query"]  = "query hotel_shopPropAvail($language: String!, $ctyhocn: String!, $guestId: BigInt, $input: ShopPropAvailQueryInput!) { hotel(ctyhocn: $ctyhocn, language: $language) {shopAvail(guestId: $guestId, input: $input) { roomTypes {roomTypeName roomTypeDesc roomOccupancy roomRates { __typename ...RoomAvailabilityRateFragment } } } } } fragment RoomAvailabilityRateFragment on ShopRoomTypeRate { rateAmount ratePlan { ratePlanName ratePlanDesc ratePlanCode confidentialRates specialRateType } }"
      data["variables"]["input"]["specialRates"] = {"groupCode" => @group_code}
    end
    url = "https://m.hilton.io/graphql/customer?type=ShopMultiPropAvailQuery&operationName=shopMultiPropAvail_hotelSummaryOption&origin=HotelSearchResultsFragment&pod=android"
    headers = @base_headers.dup
    headers["authorization"] = "Bearer "+bearer
    headers["forter-mobile-uid"] = @device_id
    headers["x-hilton-anonymous"] = "true"
    headers["dx-platform"] = "mobile"
    res = @mechanize.post(url, data.to_json, headers)
    @parsed_content = JSON.parse(res.body)
  end

  def get_content
    msg = []
    rooms = @parsed_content["data"]["hotel"]["shopAvail"]["roomTypes"]
    if rooms.empty?
      msg << "No room available for these dates"
    else
      msg << "Available rooms:"
      msg << "<ul>"
      rooms.each do |room|
        msg << "  <li>#{room['roomTypeName']} (#{room['roomOccupancy']} pers):</li>"
        msg << "  <ul>"
        room['roomRates'].each do |rate|
#          next unless rate["ratePlan"]["ratePlanName"] == "Flexible Rate"
          price = rate["ratePlan"]["rateAmountFmt"] || rate["rateAmount"]
          msg << "    <li>#{rate["ratePlan"]["ratePlanName"]} #{price}</li>"
          price
        end
        msg << "  </ul>"
      end
      msg << "</ul>"
    end
    return msg.join("\n")
  end


end

# Play around with https://forum.xda-developers.com/t/apklab-android-reverse-engineering-workbench-for-vs-code.4109409/
# and mitmproxy in ordier to get app_id & device_id
#
# Get hotel code (ie: 'CDGTPWA') from the 'ctyhocn' URL parameter on Hilton website
#
# Example:
# Hilton.new(
#     start_date: "2024-03-09",
#     end_date: "2024-03-15",
#     hotel_code: "XXXXXXX",
#     device_id: "10a9c65bcd612341",
#     app_id: "98bc7acd-1234-1234-1234-abcdef123456",
#     every: 60*60,
#     test: __FILE__ == $0
# ).update
