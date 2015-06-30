# coding: utf-8
require 'llama/listener'
require 'llama/listener_list'
require 'llama/callback'
require 'llama/utils/object'
require 'llama/plugin'
require 'llama/plugin_list'

require 'active_support/core_ext/object/try'
require 'ostruct'

module Llama
  class Bot
    attr_reader :callback
    attr_reader :listeners

    def initialize(&b)
      @listeners = ListenerList.new
      @service = nil
      @callback = Callback.new(self)
      @semaphores_mutex = Mutex.new
      @semaphores = Hash.new { |h, k| h[k] = Mutex.new }
      @callback = Callback.new(self)
      @plugins = PluginList.new(self)

      instance_eval(&b) if block_given?
    end

    def service(name, &block)
      raise 'error' unless @service.nil?

      config = OpenStruct.new(:username => '', :password => '', :name => '')
      yield config

      require("llama/services/#{name}/#{name}")
      capitalized_name = name.to_s.capitalize
      cls = 'Llama::' << capitalized_name << '::' << capitalized_name << 'Service'
      cls = Utils::class_from_string(cls)
      @service = cls.new(self, config)
    end

    def synchronize(name, &block)
      # Must run the default block +/ fetch in a thread safe way in order to
      # ensure we always get the same mutex for a given name.
      semaphore = @semaphores_mutex.synchronize { @semaphores[name] }
      semaphore.synchronize(&block)
    end

    def plugin(*plugins)
      plugins.each do |p|
        raise "class needed" unless p.class == Class

        puts "#{p} loaded"
        @plugins.register(p)
      end
    end

    def dispatch(msg)
      @listeners.dispatch(:message, msg)
      @plugins.dispatch(msg)
    end

    def on(regex = //, *args, &block)
      event = :message
      regex = Regexp.new("^#{regex}$") if regex.class == String

      listener = Listener.new(self, event, regex, *args, &block)
      @listeners.register(listener)

      return listener
    end

    def start
      @service.start
    end
  end
end