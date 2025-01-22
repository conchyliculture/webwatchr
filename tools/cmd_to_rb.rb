data = File.read(ARGV[0])

unless data.start_with?("curl")
  raise StandardError, "Need a curl command"
end

$stdout.write "cmd = [\n"
data.split("-H").each do |part|
  case part
  when /'Cookie: (.*)$/
    $stdout.write "  \"'Cookie: \" + [\n"
    Regexp.last_match(1).split('; ').each do |c|
      $stdout.write "    \"#{c}\",\n"
    end
    $stdout.write "  ].join('; '),\n"
  else
    $stdout.write "  \"#{part.strip.gsub('"', '\\"')}\",\n"
  end
end

$stdout.write("]\n")

$stdout.write("puts cmd.join(' -H ')")
