# frozen_string_literal: true
module Dynflow
  class Director
    class FlowManager
      include Algebrick::TypeCheck

      attr_reader :execution_plan, :cursor_index

      def initialize(execution_plan, flow)
        @execution_plan = Type! execution_plan, ExecutionPlan
        @flow           = flow
        @cursor_index   = {}
        @cursor         = build_root_cursor
      end

      def done?
        @cursor.done?
      end

      # @return [Set] of steps to continue with
      def what_is_next(flow_step)
        return [] if flow_step.state == :suspended

        success = flow_step.state != :error
        return cursor_index[flow_step.id].what_is_next(flow_step, success)
      end

      # @return [Set] of steps to continue with
      def start
        return @cursor.what_is_next.tap do |steps|
          raise 'invalid state' if steps.empty? && !done?
        end
      end

      def promise_flow(flow, &block)
        flow_to_promises(flow, Concurrent::Promises.resolved_event, &block)
      end

      private

      def build_root_cursor
        # the root cursor has to always run against sequence
        sequence = @flow.is_a?(Flows::Sequence) ? @flow : Flows::Sequence.new([@flow])
        return SequenceCursor.new(self, sequence, nil)
      end

      def flow_to_promises(flow, parent_promise, &block)
        case flow
        when Flows::Atom
          done = Concurrent::Promises.resolvable_future
          parent_promise.then do
            yield done, flow.step_id
          end
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
