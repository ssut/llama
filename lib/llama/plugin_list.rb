module Llama
  class PluginList < Array
    def initialize(bot)
      @bot = bot
      @matchers = {}
      super()
    end

    def register(plugin)
      self << plugin.new(@bot)
    end

    def unregister(*plugins)
      self.each do |plugin|
        self.delete(plugin)
      end
    end

    def threads
      self.map { |p| p.threads }.flatten
    end

    def dispatch(msg)
      threads = []

      self.each do |plugin|
        threads << plugin.dispatch(msg)
      end

      threads
    end

    def stop_all(force=false)
      self.each { |p| p.stop(force) }
    end
  end
end
