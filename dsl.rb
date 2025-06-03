#!/usr/bin/env ruby -I ../lib -I lib
require "webwatchr"

Webwatchr::Main.new do
  add_default_alert :email do
    set :smtp_port, 25
    set :smtp_server, "localhost"
    set :dest_addr, "renzokuken@renzokuken.eu"
    set :from_addr, "webwatchr@renzokuken.eu"
  end

  add_default_alert :telegram do
    set :token, "959829453:AAHRmVQPBTup8IA5-g2xEl4EUGmgQFQFAx8"
    set :chat_id, 411_527_669
  end

  update PostCH do
    track_id "LS203038460CH"
  end
end
