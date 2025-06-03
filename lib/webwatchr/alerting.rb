require 'telegram/bot'
require_relative "./logger"

module Webwatchr
  module Alerting
    class Base
      include Loggable
      def update()
        raise StandardError, "Implement me lol"
      end

      def self.create(&block)
        new.instance_eval(&block)
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
      def alert(site)
        raise StandardError, "Need to pass a Site instance" unless site

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
      def alert(site)
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
  end
end
