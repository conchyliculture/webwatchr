Dir['./sites/**/*.rb'].sort.each do |path|
  require_relative path
end

SITES_TO_WATCH = [
  UPS.new(
    track_id: "899997501792460130",
    every: 30 * 60
  )
].freeze
