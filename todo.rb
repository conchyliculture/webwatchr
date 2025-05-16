module TODO
  Dir[File.join(__dir__, './sites/**/*.rb')].sort.each do |path|
    puts "Loading #{path}" if $VERBOSE
    require path
  end

  class DummySite < Site::SimpleString
    def initialize()
      super(url: "https://www.toto.fr")
    end
    def get_content
      return ResultObject.new("coin")
    end
  end

  # Add instances here
  SITES_TO_WATCH = [
    # Example:
    #
    DummySite.new()
  ]
end

if __FILE__ == $0
  TODO::SITES_TO_WATCH.each do |site|
    site.update(test: true)
  end
end
