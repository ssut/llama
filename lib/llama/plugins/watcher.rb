# encoding: utf-8
require 'digest'

module Llama
  module EmbedPlugin
    class Conn < EM::Connection
      attr_accessor :server

      def receive_data(data)
        data = data.force_encoding('UTF-8')
        p data
        server.execute(data)
      end
    end

    class WatcherPlugin
      include Llama::Plugin
      match /(^$|.+)/, :on_message

      def init
        @server = nil
        @sign = EM::start_server "127.0.0.1", 44445, Conn do |c|
          c.server = self
          @server = c
        end
        @pwd = Dir.pwd
        @group =  @bot.service.groups.find { |grp| grp.id == 'c42f6bd5b8e961f6373fcb2c0411b7c39' }
      end

      def sticker(sticker, &callback)
        url = sticker['url']
        hash = Digest::MD5.hexdigest(url)
        cache = "#{@pwd}/tmp/#{hash}.png"
        unless File.exists?(cache)
          http = EM::HttpRequest.new(url, :connect_timeout => 3, :inactivity_timeout => 10).get
          file = File.open(cache, 'wb')
          http.stream { |chunk|
            file.write(chunk)
          }
          http.callback {
            file.close
            callback.call(cache)
          }
        else
          callback.call(cache)
        end
      end

      def on_message(msg, captures)
        if msg.content_type == :image
          msg.download_content do |ok, file|
            return unless ok
            @server.send_data("1|#{file.path}|#{msg.user.name}")
          end
        elsif msg.content_type == :sticker
          sticker(msg.sticker) do |path|
            @server.send_data("1|#{path}|#{msg.user.name}")
          end
        elsif msg.content_type == :text
          @server.send_data("0|@#{msg.user.name}: #{msg.raw}")
        end
      end

      def execute(message)
        @group.send_message(message, nil)
      end
    end
  end
end
