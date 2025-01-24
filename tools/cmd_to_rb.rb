# Pass a file where you copied a "Saved as curl" command from your browser
#
# This will generate a ruby script, multilined, easy to comment out lines, that will generate the same command, for testing
#
# Example:
# ruby _cmd_to_rb /tmp/curl.sh > /tmp/curl.rb
#
# hack hack on /tmp/curl.rb to remove cookies, headers, etc.
#
# ruby /tmp/curl.rb > /tmp/newcurl.sh
# bash /tmp/newcurl.sh
#
# and make sure you get the results you need
#
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
