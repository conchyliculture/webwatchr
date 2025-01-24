# Simple HTTP Archive (.har) file parser.
require "json"

class HARParser
  class Entry
    def initialize(dict)
      @dict = dict
    end

    def text?()
      if (@dict.dig("response", "content", "mimeType") || '') =~ /^(text\/html|application\/.*json)/
        return true
      else
        return false
      end
    end

    def dig(*args)
      @dict.dig(*args)
    end

    def to_s()
      req = @dict['request']
      req_headers = req['headers']
      resp = @dict['response']
      resp_headers = resp['headers']
      result = "=> #{req['method']} #{req['url']} #{req['httpVersion']}\n"
      cookies = req_headers.select { |h| h['name'] == 'Cookie' }.map { |x| x["value"].split("; ").join("\n    * ") }.join("\n")
      if cookies.size.empty?
        result << "  - Cookies: " << cookies << "\n"
      end

      result += "<= #{resp['status']}"
      if resp_headers.size.empty?
        size_h = resp_headers.select { |h| h['name'] == 'Content-Length' }
        if size_h.size.empty?
          result += " Size: #{resp_headers.select { |h| h['name'] == 'Content-Length' }[0]['value']}"
        end
      end
      result << "\n"

      if text? and resp.dig("content", "text")
        result << resp.dig("content", "text").gsub("\n", "\n        ")
      end

      result << "\n"
      result
    end

    def to_curl
      req = @dict['request']
      result_cmd = ["curl", "-X", req['method']]
      if req["httpVersion"] == "HTTP/2.0"
        result_cmd << "--http2 "
      end
      result_cmd << req["url"]
      result_cmd << req["headers"].map { |h| "-H '#{h['name'].split('-').map(&:capitalize).join('-')}: #{h['value']}'" }

      return result_cmd.join(" ")
    end
  end

  attr_accessor :entries, :text_entries

  def initialize(src)
    unless src.is_a?(File) || src.is_a?(String)
      puts 'Argument must be String or File!'
      raise ArgumentError
    end
    src = src.read() if src.is_a?(File)
    begin
      @json = JSON.parse(src)
    rescue StandardError
      puts "The input could not be parsed."
      raise JSON::ParserError
    end
    @entries = []
    @text_entries = []
    parse_entries()
  end

  def parse_entries
    @json["log"]["entries"].each do |e|
      entry = Entry.new(e)
      @entries << entry
      if entry.text?()
        @text_entries << entry
      end
    end
  end
end

def help
  puts "Usage: ruby parse_har.rb <har_file> [command]"
  puts ""
  puts "If command is not set, will display a summary of the requests that contain text content."
  puts
  puts "<command> can be either:"
  puts "  all    : display all requests and responses."
  puts "  [0-1]+ : display a specific request number in detail, in curl format."
end

if ARGV.empty?
  help()
  exit
end

entries = HARParser.new(File.read(ARGV[0])).entries
if ARGV.size == 1
  entries.each_with_index do |e, index|
    next unless e.text?

    puts "= Entry #{index} =================="
    puts e.to_s
  end
else
  case ARGV[1]
  when "all"
    entries.each_with_index do |e, index|
      puts "= Entry #{index} =================="
      puts e.to_s
    end
  when /^(\d+)$/
    entry_number = Regexp.last_match(1).to_i
    puts entries[entry_number].to_curl
  end
end
