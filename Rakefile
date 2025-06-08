task default: %w[infra_tests sites_tests]

task :infra_tests do
  ruby "tests/infra_test.rb"
end

task :sites_tests do
  Dir.glob("tests/sites/*.rb").each do |t|
    ruby t
  end
end
