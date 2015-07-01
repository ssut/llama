require 'shikashi'

module Llama
  module EmbedPlugin
    class RubySandboxPlugin
      include Llama::Plugin
      match /^rb (.+)/

      def init
        @sandbox = Shikashi::Sandbox.new
        @priv = Shikashi::Privileges.new

        [:p, :print, :puts].each { |c| @priv.allow_method c }
        @priv.instances_of(Fixnum).allow :times
        @priv.instances_of(Fixnum).allow :+
        @priv.instances_of(Fixnum).allow :*
        @priv.instances_of(Fixnum).allow :-
      end

      def execute(msg, captures)
        cmd = captures.join
        begin
          result = @sandbox.run(@priv, cmd, :timeout => 5).inspect
          result = '[nah?]' if result.nil?
          msg.reply(:text, result)
        rescue SecurityError
          msg.reply(:text, '해당 코드는 실행이 제한되어 있습니다.')
        rescue Exception => e
          msg.reply(:text, e.inspect)
        end
      end
    end
  end
end
