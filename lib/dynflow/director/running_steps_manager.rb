# frozen_string_literal: true
module Dynflow
  class Director
    # Handles the events generated while running actions, makes sure
    # the events are sent to the action only when in suspended state
    class RunningStepsManager
      include Algebrick::TypeCheck

      def initialize(world)
        @world         = Type! world, World
        @running_steps = {}
        # Mapping between step ids and futures, when the future is fulfilled, then the step is done
        @step_futures = {}
        @running_step_futures = Hash.new { |h,k| h[k] = [] }
      end

      def terminate
        abort :termination
      end
      
      def restart
        abort :restart
      end
      
      def abort(reason)
        @running_step_futures.keys.each do |step_id|
          pending_step_future(step_id)&.reject reason
          @step_futures.delete(step_id)&.reject reason
        end
      end

      def add(step, work, done, item_future)
        Type! step, ExecutionPlan::Steps::RunStep
        @running_steps[step.id] = step
        # we make sure not to run any event when the step is still being executed
        @step_futures[step.id] = done
        @running_step_futures[step.id] << item_future
        self
      end

      # @returns [TrueClass|FalseClass, Array<WorkItem>]
      def done(step)
        Type! step, ExecutionPlan::Steps::RunStep
        # update the step based on the latest finished work
        @running_steps[step.id] = step

        item_future = pending_step_future(step.id)
        if step.state == :suspended
          item_future&.fulfill true
          return
        end
        @running_steps.delete(step.id)
        item_future&.reject false
        future = @step_futures.delete step.id
        @running_step_futures.delete step.id
        if [:success, :skipped].include? step.state
          future.fulfill true
        else
          future.reject false
        end
      end

      def try_to_terminate
        @running_steps.delete_if do |_, step|
          step.state != :running
        end
        return @running_steps.empty?
      end

      # @returns [Array<WorkItem>]
      def event(event)
        Type! event, Event

        step = @running_steps[event.step_id]
        unless step
          event.result.reject UnprocessableEvent.new('step is not suspended, it cannot process events')
          return []
        end

        [create_next_event_work_item(step, event)]
      end

      # turns the first event from the queue to the next work item to work on
      def create_next_event_work_item(step, event)
        EventWorkItem.new(event.request_id, event.execution_plan_id, step, event.event, step.queue, @world.id)
      end
      
      def next(step_id)
        last = @running_step_futures[step_id].last
        @running_step_futures[step_id] << Concurrent::Promises.resolvable_future
        yield last
      end

      def pending_step_future(step_id)
        @running_step_futures[step_id].find { |f| !(f.fulfilled? || f.rejected?) }
      end
    end
  end
end
