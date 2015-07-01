# coding: utf-8
require 'llama/logger'
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
    include Logging

    attr_reader :callback
    attr_reader :listeners

    def initialize(&b)
      @listeners = ListenerList.new
      @service = nil
      @callback = Callback.new(self)
      @semaphores_mutex = Mutex.new
      @semaphores = Hash.new { |h, k| h[k] = Mutex.new }
      @callback = Callback.new(self)
      @plugins_classes = []
      @plugins = PluginList.new(self)

      instance_eval(&b) if block_given?
    end

    def service(name, &block)
      raise "A service already exists!" unless @service.nil?

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
      @plugins_classes = plugins.map do |p|
        raise "Plugin must be a Class object" unless p.class == Class
        p
      end
    end

    def dispatch(msg)
      return if msg.nil?
      @listeners.dispatch(:message, msg)
      @plugins.dispatch(msg)
    end

    def on(regex = //, *args, &block)
      event = :message
      if regex.class == String
        regex = Regexp.escape(regex)
        regex = Regexp.new("^#{regex}$")
      end

      listener = Listener.new(self, event, regex, *args, &block)
      @listeners.register(listener)

      return listener
    end

    def start
      @plugins_classes.each do |p|
        logger.info("Load Plugin: #{p}")
        @plugins.register(p)
      end

      logger.info('Start Service')
      @service.start
    end
  end
end
