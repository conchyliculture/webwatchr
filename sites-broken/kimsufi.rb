#!/usr/bin/ruby
require_relative "../webwatchr/site"

class Kimsufi < Site::SimpleString
  Kimsufi::TYPETONAME = {
    "160sk6" => "KS-6",
    "160sk5" => "KS-5",
    "160sk4" => "KS-4A",
    "160sk41" => "KS-4B",
    "160sk42" => "KS-4C",
    "160sk3" => "KS-3A",
    "160sk31" => "KS-3B",
    "160sk32" => "KS-3C",
    "160sk2" => "KS-2A",
    "160sk21" => "KS-2B",
    "160sk22" => "KS-2C",
    "160sk23" => "KS-2D",
    "161sk2" => "KS-2E",
    "160sk1" => "KS-1",

    "141game1" => "GAME-1",
    "141game2" => "GAME-2",

    "142sys4" => "SYS-IP-1",
    "142sys5" => "SYS-IP-2",
    "142sys8" => "SYS-IP-4",
    "142sys6" => "SYS-IP-5",
    "142sys10" => "SYS-IP-5S",
    "142sys7" => "SYS-IP-6",
    "142sys9" => "SYS-IP-6S",

    "143sys13" => "E3-SSD-1",
    "143sys10" => "E3-SSD-2",
    "143sys11" => "E3-SSD-3",
    "143sys12" => "E3-SSD-4",

    "143sys4" => "E3-SAT-1",
    "143sys1" => "E3-SAT-2",
    "143sys2" => "E3-SAT-3",
    "143sys3" => "E3-SAT-4",

    "141bk1" => "BK-8T",
    "141bk2" => "BK-24T"
  }.freeze

  def initialize(machines:, every: 5 * 60)
    @machines = machines
    super(url: "https://ws.ovh.com/dedicated/r2/ws.dispatcher/getAvailability2", every: every)
  end

  def get_content
    dispos = {}
    JSON.parse(@html_content)["answer"]["availability"].each do |m|
      machine = Kimsufi::TYPETONAME[m["reference"]]
      next unless @machines.include?(machine)

      available_zones = (m["zones"] || []).reject { |mm| mm["availability"] =~ /^(unavailable|unknown)$/ }.map { |z| z["zone"] }
      unless available_zones.empty?
        dispos[machine] = available_zones
      end
    end
    res = ""
    dispos.each do |machine, av|
      res << "#{machine} is available in zones: #{av.join(', ')}\n"
    end
    return ResultObject.new(res)
  end
end

# Example:
#
# Kimsufi.new(
#     machines: ["KS-1", "KS-2B"])
