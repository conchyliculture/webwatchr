require_relative "../webwatchr/site"
require "json"
require "net/http"
require "nokogiri"

class Chronopost < Site::SimpleString
  def track_id(track_id)
    @track_id = track_id
    @url = "https://www.chronopost.fr/tracking-no-cms/suivi-page?langue=fr&listeNumerosLT=#{track_id}"
    self
  end

  def initialize
    super()
    @update_interval = 6 * 60 * 60
    @parsed_json = nil
  end

  def pull_things()
    uri = URI("https://www.chronopost.fr/tracking-no-cms/suivi-colis?listeNumerosLT=#{@track_id}&langue=fr")
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0'
    req['Accept'] = 'application/json, text/javascript, */*; q=0.01'
    req['X-Requested-With'] = 'XMLHttpRequest'
    req['Referer'] = @url

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.set_debug_output $stderr if $VERBOSE
    http.start do |h|
      resp = h.request(req)
      @parsed_json = JSON.parse(resp.body)
    end
  end

  def cell_text(cell)
    cell.css("br").each { |br| br.replace(" ") }
    cell.text.gsub(/\s+/, ' ').strip
  end

  def extract_content()
    tab_html = @parsed_json['tab']
    raise Site::ParseError, "No tracking data in response for #{@track_id}" if tab_html.nil? || tab_html.strip.empty?

    res = Site::SimpleString::ListResult.new()
    Nokogiri::HTML(tab_html).css("tr.toggleElmt").each do |row|
      cells = row.css("td")
      next if cells.size < 2

      date = cell_text(cells[0])
      status = cell_text(cells[1])
      msg = "#{date}: #{status}"

      if cells[2]
        extra = cell_text(cells[2])
        msg += " [#{extra}]" unless extra.empty?
      end

      res << msg
    end

    res
  end
end

# Example:
#
#  update Chronopost do
#    track_id "XM12012082TS"
#  end
