#!/usr/bin/ruby

require_relative "../lib/site"

require "json"

class DPD < Site::SimpleString
  def initialize(track_id:, every:, comment: nil)
    super(
      url: "https://tracking.dpd.de/rest/plc/en_US/#{track_id}",
      every: every,
      comment: comment,
    )
    @track_id = track_id
  end

  def get_content
    res = ["<ul>"]
    j = JSON.parse(@html_content)
    if j
      unless j["parcellifecycleResponse"]["parcelLifeCycleData"]
        return "No info for #{@track_id}"
      end

      j["parcellifecycleResponse"]["parcelLifeCycleData"]["statusInfo"].select { |i| i["statusHasBeenReached"] }.each { |x|
        date = x["date"]
        place = x["location"]
        descr = x["description"]["content"].join(' ')
        res << "<li>#{date} #{place} #{descr}</li>"
      }
    else
      raise Site::ParseError, "Please verify the DPD tracking ID"
    end
    res << ["</ul>"]
    return res.join("\n")
  end
end

# Example:
#
# DPD.new(
#     track_id: "000000000000",
#     every: 30*60,
# ).update
