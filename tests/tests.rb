require_relative "infra_test"
Dir[File.join(__dir__, '../sites/**/*.rb')].sort.each do |path|
  require path
end

Dir[File.join(__dir__, 'sites/*.rb')].sort.each do |path|
  require path
end
