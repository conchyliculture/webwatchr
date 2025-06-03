#!/usr/bin/env ruby -I ../lib -I lib
require "webwatchr"

Webwatchr::Main.new do
  add_default_alert :email do
    smtp_port 25
    smtp_server "localhost"
    dest_addr "renzokuken@renzokuken.eu"
    from_addr "webwatchr@renzokuken.eu"
  end

  add_default_alert :telegram do
    token "959829453:AAHRmVQPBTup8IA5-g2xEl4EUGmgQFQFAx8"
    chat_id 411_527_669
  end

  update PostCH do |site|
    site.track_id = "LS203038460CH"
  end
end
