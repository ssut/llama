module Llama
  class Listener
    attr_reader :bot
    attr_reader :event
    attr_reader :regex
    attr_reader :args
    attr_reader :block
    attr_reader :group

    # @api private
    attr_reader :thread_group

    def initialize(bot, event, regex, options = {}, &block)
      options = {
        group: nil,
        execute_in_callback: true,
        args: []
      }.merge(options)
      @bot = bot
      @event = event
      @regex = regex
      @args = options[:args]
      @execute_in_callback = options[:execute_in_callback]
      @block = block
    end

    def unregister
      @bot.listeners.unregister(self)
    end

    def stop
      @thread_group.list.each do |thread|
        thread.join(10)
        thread.kill
      end
    end

    def call(message, captures, user)
      # @block.call(message, captures, *@args)
      # return
      EM.next_tick do
        p Thread.current
        begin
          if @execute_in_callback
            @bot.callback.instance_exec(message, captures, *@args, &block)
          else
            @block.call(message, captures, *@args)
          end
        rescue => e
          # error
        ensure
          # done
        end
      end
    end
  end
end
