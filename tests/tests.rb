Dir['./sites/**/*.rb'].sort.each do |path|
  require_relative path
end
