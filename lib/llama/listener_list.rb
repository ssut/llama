require 'thread'
require 'set'

module Llama
  class ListenerList
    include Enumerable

    def initialize
      @listeners = Hash.new { |h, k| h[k] = [] }
      @mutex = Mutex.new
    end

    def register(listener)
      @mutex.synchronize do
        @listeners[listener.event] << listener
      end
    end

    def unregister(*listeners)
      @mutex.synchronize do
        listeners.each do |listener|
          @listeners[listener.event].delete(listener)
        end
      end
    end

    def find(type, msg = nil)
      if listeners = @listeners[type]
        if msg.nil?
          return listeners
        end

        listeners = listeners.select { |listener|
          msg.match(listener.regex)
        }.group_by { |listener| listener.group }

        listeners.values_at(*(listeners.keys - [nil])).map(&:first) + (listeners[nil] || [])
      end
    end


    def dispatch(event, msg = nil, *args)
      threads = []

      if listeners = find(event, msg)
        already_run = Set.new
        listeners.each do |listener|
          next if already_run.include?(listener.block)

          if msg
            captures = msg.match(listener.regex).captures
          else
            captures = []
          end
        
          threads << listener.call(msg, captures, args)
        end
      end

      threads
    end

    def each(&block)
      @listeners.values.flatten.each(&block)
    end

    def stop_all
      each { |l| l.stop }
    end
  end
end