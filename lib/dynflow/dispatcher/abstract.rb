# frozen_string_literal: true
module Dynflow
  module Dispatcher
    class Abstract < Actor
      def connector
        @world.connector
      end

      def respond(request_envelope, response)
        return unless request_envelope.expect_reply
        response_envelope = request_envelope.build_response_envelope(response, @world)
        connector.send(response_envelope)
      end
    end
  end
end
