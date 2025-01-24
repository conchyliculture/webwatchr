Dir[File.join(__dir__, '../sites/**/*.rb')].sort.each do |path|
  puts "loading #{path}"
  require path
end
