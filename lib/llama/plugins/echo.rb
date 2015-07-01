require 'mechanize'

module Llama
  module EmbedPlugin
    class EchoPlugin
      include Llama::Plugin
      match /^따라해$/, :start
      match /^따라하지마$/, :stop
      match /(.+)/

      def init
        @list = {}
      end

      def start(msg, captures)
        if @list.include?(msg.room.id) and @list[msg.room.id].include?(msg.user.id)
          msg.reply(:text, "이미 #{msg.user.name}님의 말을 따라하고 있어요.")
          return
        end
        @list[msg.room.id] = [] unless @list.include?(msg.room.id)
        @list[msg.room.id] << msg.user.id
        msg.reply(:text, "#{msg.user.name}님의 말을 따라합니다.")
      end

      def stop(msg, captures)
        if list = @list[msg.room.id]
          if list.include?(msg.user.id)
            @list[msg.room.id].delete(msg.user.id)
            msg.reply(:text, "#{msg.user.name}님의 말을 따라하지 않습니다.")
          else
            msg.reply(:text, "#{msg.user.name}님의 말은 따라하고 있지 않습니다.")
          end
        end
      end

      def execute(msg, captures)
        text = captures.join
        return if text == '따라해' or text == '따라하지마'

        if list = @list[msg.room.id]
          if list.include?(msg.user.id)
            msg.reply(:text, text)
          end
        end
      end
    end
  end
end
