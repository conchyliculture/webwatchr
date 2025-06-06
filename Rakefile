task default: %w[test]

task :test do
  ruby "tests/tests.rb"
  ruby "tests/infra_test.rb"
  Dir.glob("tests/sites/*.rb").each do |t|
    ruby t
  end
end
