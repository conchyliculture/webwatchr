module TODO
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
end

if __FILE__ == $0
  TODO::SITES_TO_WATCH.each do |site|
    site.update(test: true)
  end
end
