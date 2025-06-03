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
    end

    class EmailAlert < Base
      def smtp_port(val)
        @smtp_port = val
        return self
      end

      def smtp_server(val)
        @smtp_server = val
        return self
      end

      def from_addr(val)
        @from = val
        return self
      end

      def dest_addr(val)
        @to = val
        return self
      end

      def alert(site)
        raise StandardError, "Need to pass a Site instance" unless site

        subject = site.get_email_subject() || "Update from #{site.class}"

        formatted_content = site.generate_html_content()

        msgstr = <<~END_OF_MESSAGE
          From: #{@from}
          To: #{@to}
          MIME-Version: 1.0
          Content-type: text/html; charset=UTF-8
          Subject: [Webwatchr] #{subject}

          Update from #{site.get_email_url()}

          #{formatted_content}
        END_OF_MESSAGE

        begin
          Net::SMTP.start(@smtp_server, @smtp_port, starttls: false) do |smtp|
            raise StandardError, "from address cannot be nil" unless @from

            smtp.send_message(msgstr, @from, @to)
            logger.debug("Sending mail to #{@to}")
          end
        rescue Net::SMTPFatalError => e
          logger.error "Couldn't send email from #{@from} to #{@to}. #{@smtp_server}:#{@smtp_port} said #{e.message}"
        end
      end
    end

    class TelegramAlert < Base
      def token(val)
        @token = val
        self
      end

      def chat_id(val)
        @chat_id = val
        self
      end

      def alert(site)
        bot = Telegram::Bot::Client.new(@token)
        msg_pieces = [site.get_email_subject]
        msg_pieces << site.get_email_url()

        msg_pieces += site.generate_telegram_message_pieces()
        msg_pieces = msg_pieces.map { |x| x.size > 4096 ? x.split("\n") : x }.flatten()
        split_msg = msg_pieces.each_with_object(['']) { |str, sum|
          sum.last.length + str.length > 4000 ? sum << "#{str}\n" : sum.last << "#{str}\n"
        }

        split_msg.each do |m|
          bot.api.send_message(chat_id: @chat_id, text: m)
        end
      rescue LoadError => e
        puts "Please open README.md to see how to make Telegram alerting work"
        raise e
      end
    end
  end
end
