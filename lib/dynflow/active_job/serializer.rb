# frozen_string_literal: true

require 'active_job/serializers'
module Dynflow
  module ActiveJob
    class Serializer < ::ActiveJob::Serializers::ObjectSerializer
      def serialize?(arg)
        true
      end

      def serialize(value)
        super(Dynflow.serializer.dump(value))
      end

      def deserialize(value)
        value = Utils::IndifferentHash.new(value) if value.is_a? Hash
        Dynflow.serializer.load(value)
      end
    end
  end
end
