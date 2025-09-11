# frozen_string_literal: true

module Dynflow
  class Director
    class FlowManager
      attr_reader :cursor_index

      def initialize(flow)
        @flow           = flow
        @cursor_index   = {}
        @cursor         = build_root_cursor
      end

      def done?
        @cursor.done?
      end

      # @return [Set] of steps to continue with
      def what_is_next(flow_step_id, state)
        return [] if state == :suspended

        success = state != :error
        return cursor_index[flow_step_id].what_is_next(flow_step_id, success)
      end

      # @return [Set] of steps to continue with
      def start
        return @cursor.what_is_next.tap do |steps|
          raise 'invalid state' if steps.empty? && !done?
        end
      end

      private

      def build_root_cursor
        # the root cursor has to always run against sequence
        sequence = @flow.is_a?(Flows::Sequence) ? @flow : Flows::Sequence.new([@flow])
        return SequenceCursor.new(self, sequence, nil)
      end
    end
  end
end
