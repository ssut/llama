# coding: utf-8
require 'eventmachine'
require 'em-http-request'
require 'wrest'
require 'wrest/multipart'
require 'active_support/core_ext/object/try'
require 'ostruct'
require 'tempfile'

require 'llama/patch'
require 'llama/logger'
require 'llama/utils/object'
require 'llama/utils/http'
require 'llama/listener'
require 'llama/listener_list'
require 'llama/callback'
require 'llama/plugin'
require 'llama/plugin_list'

module Llama
  class Bot
    include Logging

    attr_reader :callback
    attr_reader :listeners
    attr_accessor :messages

    def initialize(&b)
      @listeners = ListenerList.new
      @service = nil
      @service_conf = nil
      @callback = Callback.new(self)
      @callback = Callback.new(self)
      @plugins_classes = []
      @plugins = PluginList.new(self)
      @messages = EM::Channel.new
      Wrest::AsyncRequest.default_to_em!

      instance_eval(&b) if block_given?
    end

    def service(name, &block)
      raise "A service already exists!" unless @service.nil?

      config = OpenStruct.new(:username => '', :password => '', :name => '')
      yield config
      @service = name
      @service_conf = config
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

    def start!(&b)
      EM.run do
        name = @service
        require("llama/services/#{name}/#{name}")
        capitalized_name = name.to_s.capitalize
        cls = 'Llama::' << capitalized_name << '::' << capitalized_name << 'Service'
        cls = Utils::class_from_string(cls)
        @service = cls.new(self, @service_conf)
        yield @service

        @plugins_classes.each do |p|
          logger.info("Load Plugin: #{p}")
          @plugins.register(p)
        end

        @messages.subscribe do |msg|
          self.dispatch(msg)
        end

        logger.info('Start Service')
        EM.defer do
          @service.start!
        end
      end
    end
  end
end
