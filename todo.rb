Dir['./sites/**/*.rb'].sort.each do |path|
  require_relative path
end

# Add instances here
SITES_TO_WATCH = [
  # Example:
  #
  #  Bsky.new(
  #    account: "swiftonsecurity.com",
  #    every: 30 * 60
  #  )
]
