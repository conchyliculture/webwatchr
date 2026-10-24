require "net/smtp"
require "securerandom"
require "stringio"
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
      IDENTIFIER = :email
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

        formatted_content, images = inline_images(site, site.generate_html_content() || "")

        headers = <<~END_OF_HEADERS
          From: #{@config[:from_addr]}
          To: #{@config[:dest_addr]}
          MIME-Version: 1.0
          Subject: [Webwatchr] #{subject}
        END_OF_HEADERS
        html_part = <<~END_OF_HTML
          Content-type: text/html; charset=UTF-8

          Update from #{site.get_email_url()}

          #{formatted_content}
        END_OF_HTML

        msgstr = if images.empty?
                   headers + html_part
                 else
                   boundary = "webwatchr-#{SecureRandom.hex(12)}"
                   parts = [html_part] + images.map { |cid, img| image_part(cid, img) }
                   headers + "Content-Type: multipart/related; boundary=\"#{boundary}\"\n\n" +
                     parts.map { |p| "--#{boundary}\n#{p}" }.join("\n") + "\n--#{boundary}--\n"
                 end

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

      # Points every remote <img> of the HTML that the site already downloaded (see Site#fetch_images)
      # to inline attachments instead. Other pictures are left as remote links.
      #
      # Returns the new HTML, and a Hash of content-id => image
      def inline_images(site, html)
        images = {}
        cids = {}
        new_html = html.gsub(Site::IMG_SRC_REGEX) do
          prefix, quote, url = Regexp.last_match.captures
          unless cids.key?(url)
            img = site.image(url)
            cids[url] = img && "img#{cids.size}.#{SecureRandom.hex(8)}@webwatchr"
            images[cids[url]] = img if img
          end
          cids[url] ? "#{prefix}#{quote}cid:#{cids[url]}#{quote}" : Regexp.last_match(0)
        end
        return [new_html, images]
      end

      def image_part(cid, img)
        filename = img[:filename].gsub(/[^\w.-]/, '_')
        return <<~END_OF_PART
          Content-Type: #{img[:content_type]}; name="#{filename}"
          Content-Transfer-Encoding: base64
          Content-ID: <#{cid}>
          Content-Disposition: inline; filename="#{filename}"

          #{[img[:data]].pack('m')}
        END_OF_PART
      end
    end

    class TelegramAlert < Base
      IDENTIFIER = :telegram
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
        # Consecutive text pieces are grouped in as few messages as possible,
        # pictures are sent one by one, in order.
        msg_pieces.compact.chunk_while { |a, b| !a.is_a?(Site::Image) && !b.is_a?(Site::Image) }.each do |chunk|
          if chunk.first.is_a?(Site::Image)
            send_photo(bot, site, chunk.first)
          else
            send_text(bot, chunk)
          end
        end
      end

      def send_text(bot, msg_pieces)
        msg_pieces = msg_pieces.map { |x| x.size > 4096 ? x.split("\n") : x }.flatten()
        split_msg = msg_pieces.each_with_object(['']) { |str, sum|
          sum.last.length + str.length > 4000 ? sum << "#{str}\n" : sum.last << "#{str}\n"
        }

        split_msg.each do |m|
          bot.api.send_message(chat_id: @config[:chat_id], text: m)
        end
      end

      def send_photo(bot, site, image)
        caption = image.caption.to_s
        img = site.image(image.url)
        if img
          photo = Faraday::Multipart::FilePart.new(StringIO.new(img[:data]), img[:content_type], img[:filename])
          bot.api.send_photo(chat_id: @config[:chat_id], photo: photo, caption: caption[0, 1024])
          send_text(bot, [caption[1024..]]) if caption.size > 1024
        else
          send_text(bot, [caption, image.url].reject(&:empty?))
        end
      rescue Telegram::Bot::Exceptions::ResponseError => e
        logger.warn "Telegram refused picture #{image.url}: #{e.message}"
        send_text(bot, [caption, image.url].reject(&:empty?))
      end
    end

    class StdoutAlert < Base
      IDENTIFIER = :stdout
      def alert(site)
        super(site)
        msg = "Update rom #{site.url}\n#{site.generate_html_content}"
        puts(msg)
      end
    end
  end
end
