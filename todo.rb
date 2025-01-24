Dir[File.join(__dir__, './sites/**/*.rb')].sort.each do |path|
  puts "Loading #{path}" if $VERBOSE
  require path
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
