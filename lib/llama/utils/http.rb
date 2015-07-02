module Llama
  module Utils
    module HTTP
      class Request < Struct.new(:url, :params, :method)
        include Llama::Logging

        DEFAULT_HEADERS     = { 'accept-encoding' => 'gzip, compressed' }.freeze
        CONNECTION_SETTINGS = { connect_timeout: 5, inactivity_timeout: 10 }.freeze

        def initialize(*args)
          super
          self.params ||= {}
          type = :query
          type = :body if self.method == 'post'
          self.params = params.has_key?(:body) ? params : { type => params }
          self.params = { file: params[:body].delete(:file) }.merge(self.params) if type == :body and params[type].has_key?(:file)
          headers = params[type].has_key?(:headers) ? { head: params[type].delete(:headers) } : {}
          self.params = { head: DEFAULT_HEADERS }.merge(headers).merge(params)
          p self.params
          logger.info("HTTP-REQUEST: #{url} #{params}")
        end

        def call(success_block, &fail_block)
          p 'called'
          http.errback(&fail_block) unless fail_block.nil?
          http.callback do
            success(&success_block)
          end unless success_block.nil?
        end

        protected
        def success
          yield Response.new(http, self)
        end

        protected

        def success
          yield Response.new(http, self)
        end

        def connection
          @connection ||= EM::HttpRequest.new(url, CONNECTION_SETTINGS)
        end

        def http(options = { redirects: 2 })
          @http ||= connection.send(method, params.merge(options))
        rescue => e
          instance_exec(e, &ERROR_CALLBACK)
        end
      end

      class Response < Struct.new(:raw_response, :request)
        include Llama::Logging

        def initialize *args
          super
          logger.debug("HTTP-RESPONSE: #{request.url} [#{code}]")
        end

        def url
          raw_response.last_effective_url
        end

        def body
          raw_response.response
        end

        def code
          raw_response.response_header.status
        end

        def headers
          raw_response.response_header
        end

        def json
          @json ||= JSON.parse(body) || {}
        end
      end
    end
  end
end
