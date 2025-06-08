require "net/smtp"
require 'telegram/bot'
require_relative "./logger"

module Webwatchr
  module Alerting
    class Base
      include Loggable
      REQUIRED_SETTINGS = [].freeze
      def validate
        missing_settings = REQUIRED_SETTINGS - @config.to_a.select { |s| s[1] }.map { |s| s[0] }
        raise StandardError, "Missing required settings for #{self.class}: #{missing_settings}" unless missing_settings.empty?
      end

      def self.create(&block)
        if block
          new.instance_eval(&block)
        else
          new
        end
      end

      def alert(site)
        raise StandardError, "Need to pass a Site instance" unless site

        validate
      end

      def initialize
        @config = {}
      end

      def set(key, val)
        @config[key] = val
        self
      end
    end

    class EmailAlert < Base
      REQUIRED_SETTINGS = %i[from_addr dest_addr smtp_server smtp_port].freeze
      # This class will send you email if content changes.
      #
      # ==== Examples
      #
      # Webwatchr::Main.new do
      #     add_default_alert :email do
      #       set :smtp_port, 25
      #       set :smtp_server, "localhost"
      #       set :dest_addr, "dest@email.eu"
      #       set :from_addr, "source@email.eu"
      #     end
      #     ....
      # "end"
      def alert(site)
        super(site)

        subject = site.get_email_subject() || "Update from #{site.class}"

        formatted_content = site.generate_html_content()

        msgstr = <<~END_OF_MESSAGE
          From: #{@config[:from_addr]}
          To: #{@config[:dest_addr]}
          MIME-Version: 1.0
          Content-type: text/html; charset=UTF-8
          Subject: [Webwatchr] #{subject}

          Update from #{site.get_email_url()}

          #{formatted_content}
        END_OF_MESSAGE

        begin
          Net::SMTP.start(@config[:smtp_server], @config[:smtp_port], starttls: false) do |smtp|
            raise StandardError, "from address cannot be nil" unless @config[:from_addr]

            smtp.send_message(msgstr, @config[:from_addr], @config[:dest_addr])
            logger.debug("Sending mail to #{@config[:dest_addr]}")
          end
        rescue Net::SMTPFatalError => e
          logger.error "Couldn't send email from #{@config[:from_addr]} to #{@config[:dest_addr]}. #{@config[:smtp_server]}:#{@config[:smtp_port]} said #{e.message}"
        end
      end
    end

    class TelegramAlert < Base
      REQUIRED_SETTINGS = %i[token chat_id].freeze
      # This class will use a Telegram bot to send you a message if content changes.
      #
      # ==== Examples
      #
      # Webwatchr::Main.new do
      #     ...
      #     add_default_alert :telegram do
      #       set :token, "95123456YU:AArestoftoken"
      #       set :chat_id, 123456789
      #     end
      #     ....
      # "end"
      def alert(site)
        super(site)
        bot = Telegram::Bot::Client.new(@config[:token])
        msg_pieces = [site.get_email_subject]
        msg_pieces << site.get_email_url()

        msg_pieces += site.generate_telegram_message_pieces()
        msg_pieces = msg_pieces.map { |x| x.size > 4096 ? x.split("\n") : x }.flatten()
        split_msg = msg_pieces.each_with_object(['']) { |str, sum|
          sum.last.length + str.length > 4000 ? sum << "#{str}\n" : sum.last << "#{str}\n"
        }

        split_msg.each do |m|
          bot.api.send_message(chat_id: @config[:chat_id], text: m)
        end
      end
    end

    class StdoutAlert < Base
      def alert(site)
        super(site)
        msg = "Update rom #{site.url}\n#{site.generate_html_content}"
        puts(msg)
      end
    end
  end
end
