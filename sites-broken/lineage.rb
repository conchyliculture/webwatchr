require_relative "../webwatchr/site"

class Lineage < Site::Articles
  def initialize(version: '17.1', devices: nil, every: 24 * 60 * 60)
    @devices = devices
    super(url: "https://www.lineageoslog.com/changelog/#{version}?beforeDate=&afterDate=", every: every, test: test)
  end

  def get_content()
    @parsed_content.css('div.feed-element').each do |e|
      link = e.css("a.text-primary")[0]['href']
      package = e.css("small.text-success")[0].text
      device = package[/\(android_(?:device|kernel)_([^_]+)/, 1]
      pp device
      if @devices and device and not @devices.include?(device)
        next
      end

      title = e.css("strong.block")[0].text.strip

      add_article(
        { "id" => link,
          "url" => link,
          "title" => title }
      )
    end
  end
end
