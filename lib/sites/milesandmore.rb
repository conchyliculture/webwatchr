require_relative "../webwatchr/site"
require "json"

# Watches Miles & More "mileage bargains" (Award Flights at reduced miles), as
# shown on https://www.miles-and-more.com/ch/fr/spend/flights.html#mileagebargains
#
# Data comes from the public GraphQL endpoint the website widget uses.
# Every matching bargain is an Article, so you get alerted on new ones (or when
# the price of an existing one changes, since the price is part of its URL).
#
# Example:
#
#  update MilesAndMore do
#    country "CH"          # departure country (default CH), nil for all
#    from "ZRH", "GVA"     # departure airports (default: all)
#    to "BRU"              # destination airports (default: all)
#    cabin "business"      # economy or business (default: both)
#    airline "swiss"       # airline name substring (default: all)
#    max_miles 30_000      # maximum bargain price in miles
#    language "en"         # language for place names (default fr)
#  end
class MilesAndMore < Site::Articles
  ENDPOINT = "https://api.miles-and-more.com/content/v3/offers/search".freeze
  # Public key embedded in the website's page config (apiGateway).
  API_KEY = "agGBZmuTGwFXWzVDg8ckGKGBytemE1nS".freeze

  QUERY = <<~GRAPHQL.freeze
    query Offers($airQuery: AirQuery, $channelTag: String!, $context: Context,
                 $country: String, $language: String, $offerType: [String],
                 $orderBy: Order, $totalAmount: Int, $allowSamePartner: Boolean,
                 $random: Boolean) {
      offers(air: $airQuery, channelTag: $channelTag, context: $context,
             country: $country, language: $language, offerTypes: $offerType,
             orderBy: $orderBy, totalAmount: $totalAmount,
             allowSamePartner: $allowSamePartner, random: $random) {
        offers {
          aemId
          url
          validToWeb
          partner { name }
          air {
            destinationIata
            destinationName
            originList { originIata originName originCountryIso originCountryName }
            promoMiles
            regularMiles
            travelPeriodStart
            travelPeriodEnd
          }
        }
      }
    }
  GRAPHQL

  def initialize
    super()
    @url = "https://www.miles-and-more.com/ch/fr/spend/flights.html#mileagebargains"
    @update_interval = 6 * 3600
    @country = "CH"
    @site = "ch"
    @language = "fr"
    @from = []
    @to = []
    @cabin = nil
    @airline = nil
    @max_miles = nil
  end

  # --- Configuration DSL -----------------------------------------------------

  def country(iso)
    @country = iso&.to_s&.upcase
    self
  end

  def from(*iatas)
    @from = iatas.flatten.map { |i| i.to_s.upcase }
    self
  end

  def to(*iatas)
    @to = iatas.flatten.map { |i| i.to_s.upcase }
    self
  end

  def cabin(value)
    @cabin = value.to_s.downcase
    self
  end

  def airline(substr)
    @airline = substr.to_s.downcase
    self
  end

  def max_miles(miles)
    @max_miles = miles.to_i
    self
  end

  def language(code)
    @language = code.to_s.downcase
    self
  end

  # --- Fetching --------------------------------------------------------------

  def request_body
    JSON.generate(
      query: QUERY,
      variables: {
        airQuery: @country ? { preferredCountry: @country } : {},
        channelTag: "WEB",
        context: { language: @language, site: @site },
        country: "web:system/countries/#{@site}",
        language: @language,
        offerType: ["airoffer"],
        orderBy: { field: "MILES_PRICE", direction: "ASC" },
        totalAmount: 1000,
        allowSamePartner: true,
        random: false
      }
    )
  end

  # Uses libcurl rather than Net::HTTP: the API's Cloudflare front rejects
  # Ruby's HTTP client with a challenge page but accepts curl.
  def fetch_offers
    require "curb"

    c = Curl::Easy.new(ENDPOINT) do |curl|
      curl.timeout = 30
      curl.headers["Content-Type"] = "application/json"
      curl.headers["Accept"] = "application/json"
      curl.headers["X-API-Key"] = API_KEY
      curl.headers["Origin"] = "https://www.miles-and-more.com"
      curl.headers["Referer"] = "https://www.miles-and-more.com/"
      curl.headers["User-Agent"] = @useragent
    end
    c.http_post(request_body)
    raise Site::ParseError, "HTTP #{c.response_code} from #{ENDPOINT}: #{c.body_str[0, 200]}" unless c.response_code.between?(200, 299)

    c.body_str
  rescue Curl::Err::CurlError => e
    raise Site::ParseError, "Error fetching #{ENDPOINT}: #{e}"
  end

  def pull_things
    @website_html = fetch_offers
  end

  # --- Parsing ---------------------------------------------------------------

  def parse_offers(data)
    errors = data["errors"]
    raise Site::ParseError, "API error: #{errors.map { |e| e['message'] }.join('; ')}" if errors&.any?

    data.dig("data", "offers", "offers").to_a.filter_map do |o|
      air = o["air"] or next
      {
        airline: o.dig("partner", "name").to_s.strip,
        # URL looks like .../mileage-bargains/<n>/<airline>/<cabin>/<period>/<promo>/<regular>/<dest>.html
        cabin: o["url"].to_s.split("/")[-5].to_s,
        destination: air["destinationName"],
        destination_iata: air["destinationIata"],
        origins: air["originList"].to_a,
        promo_miles: air["promoMiles"].to_i,
        regular_miles: air["regularMiles"].to_i,
        travel_start: air["travelPeriodStart"],
        travel_end: air["travelPeriodEnd"],
        book_by: o["validToWeb"].to_s[0, 10],
        url: o["url"]
      }
    end
  end

  # Returns the offer's origins matching our filters, or nil if the offer
  # should be skipped.
  def matching_origins(offer)
    return nil unless @to.empty? || @to.include?(offer[:destination_iata])
    return nil if @cabin && offer[:cabin] != @cabin
    return nil if @airline && !offer[:airline].downcase.include?(@airline)
    return nil if @max_miles && offer[:promo_miles] > @max_miles

    origins = offer[:origins]
    origins = origins.select { |x| x["originCountryIso"] == @country } if @country
    origins = origins.select { |x| @from.include?(x["originIata"]) } unless @from.empty?
    origins.empty? ? nil : origins
  end

  def fmt(miles)
    miles.to_s.reverse.scan(/\d{1,3}/).join("'").reverse
  end

  def format_offer(offer, origins)
    saving = offer[:regular_miles].positive? ? ((1 - (offer[:promo_miles].to_f / offer[:regular_miles])) * 100).round : 0
    [
      "#{offer[:airline]} #{offer[:cabin]}",
      "#{origins.map { |x| x['originIata'] }.join('/')} → #{offer[:destination]} (#{offer[:destination_iata]})",
      "#{fmt(offer[:promo_miles])} miles (was #{fmt(offer[:regular_miles])}, -#{saving}%)",
      "travel #{offer[:travel_start]} → #{offer[:travel_end]}",
      "book by #{offer[:book_by]}"
    ].join(" | ")
  end

  def extract_articles
    data = JSON.parse(@website_html)
    parse_offers(data).each do |offer|
      origins = matching_origins(offer)
      next unless origins

      add_article({
                    # The URL contains the promo & regular miles, so a price change is a new article
                    "id" => offer[:url],
                    "url" => offer[:url],
                    "title" => format_offer(offer, origins)
                  })
    end
  rescue JSON::ParserError => e
    raise Site::ParseError, "Could not parse Miles & More API response: #{e.message}"
  end
end
