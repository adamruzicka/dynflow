# frozen_string_literal: true
module Dynflow
  class Director
    class FlowManager
      include Algebrick::TypeCheck

      attr_reader :execution_plan, :cursor_index

      def initialize(execution_plan, flow)
        @execution_plan = Type! execution_plan, ExecutionPlan
        @flow           = flow
      end

      class << self
        def promise_flow(flow, &block)
          flow_to_promises(flow, Concurrent::Promises.resolved_event, &block)
        end

        def flow_to_promises(flow, parent_promise, &block)
          case flow
          when Flows::Atom
            done = Concurrent::Promises.resolvable_future
            parent_promise.then do
              yield done, flow.step_id
            end.on_rejection { |value| done.reject value }
            done
          when Flows::Sequence
            flow.flows.reduce(parent_promise) do |parent, subflow|
              flow_to_promises(subflow, parent, &block)
            end
          when Flows::Concurrence
            futures = flow.flows.map do |subflow|
              flow_to_promises(subflow, parent_promise, &block)
            end
            Concurrent::Promises.zip_futures(*futures)
          end
        end
      end
    end
  end
end
