#!/usr/bin/env ruby -I ../lib -I lib
require "webwatchr"

#creds = {
#  "royalmail": {
#    "client_id": "2d37721c-d72b-407a-ba5c-2d4d14948c00",
#    "client_secret": "mE0wA4pE3nP5tG5lJ3lA2bP2aF4nL6uK4mN0wH2dP5hE8fX8pC"
#  }
#}

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

  add_default_alert :stdout

  update PostCH do
    track_id "LS203038460CH"
  end
end
