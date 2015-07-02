require 'wrest/async_request/event_machine_backend'
module Wrest
  module AsyncRequest
    EventMachineBackend.class_eval do
      def execute(request)
        request.invoke
      end
    end
  end
end
