# frozen_string_literal: true

module Dynflow
  class Director
    # Handles the events generated while running actions, makes sure
    # the events are sent to the action only when in suspended state
    class RunningStepsManager
      include Algebrick::TypeCheck

      def initialize(world)
        @world         = Type! world, World
        @running_steps = Set.new
        # enqueued work items by step id
        @work_items    = QueueHash.new(Integer, WorkItem)
        # enqueued events by step id - we delay creating work items from events until execution time
        # to handle potential updates of the step object (that is part of the event)
        @events        = QueueHash.new(Integer, Director::Event)
        @events_by_request_id = {}
        @step_queues = {}
        @halted = false
      end

      def terminate
        pending_work = @work_items.clear.values.flatten(1)
        pending_work.each do |w|
          finish_event_result(w) do |result|
            result.reject UnprocessableEvent.new("dropping due to termination")
          end
        end
      end

      def halt
        @halted = true
      end

      def add(step_id, work)
        @step_queues[step_id] = work.queue
        @running_steps << step_id
        # we make sure not to run any event when the step is still being executed
        @work_items.push(step_id, work)
        self
      end

      # @returns [TrueClass|FalseClass, Array<WorkItem>]
      def done(step_id, state)
        @work_items.shift(step_id).tap do |work|
          finish_event_result(work) { |f| f.fulfill true }
        end

        if state == :suspended
          return true, [create_next_event_work_item(step_id)].compact
        else
          while (work = @work_items.shift(step_id))
            @world.logger.debug "step #{work.execution_plan_id}:#{step_id} dropping event #{work.request_id}/#{work.event}"
            finish_event_result(work) do |f|
              f.reject(UnprocessableEvent.new("Message dropped").tap { |e| e.set_backtrace(caller) })
            end
          end
          while (event = @events.shift(step_id))
            @world.logger.debug "step #{work.execution_plan_id}:#{step_id} dropping event #{event.request_id}/#{event}"
            if event.result
              event.result.reject(UnprocessableEvent.new("Message dropped").tap { |e| e.set_backtrace(caller) })
            end
          end
          unless @work_items.empty?(step_id) && @events.empty?(step_id)
            raise "Unexpected item in @work_items (#{@work_items.inspect}) or @events (#{@events.inspect})"
          end
          @running_steps.delete(step_id)
          return false, []
        end
      end

      def try_to_terminate
        return @running_steps.empty?
      end

      # @returns [Array<WorkItem>]
      def event(event)
        Type! event, Event

        unless @running_steps.include?(event.step_id)
          event.result.reject UnprocessableEvent.new('step is not suspended, it cannot process events')
          return []
        end
        if @halted
          event.result.reject UnprocessableEvent.new('execution plan is halted, it cannot receive events')
          return []
        end

        can_run_event = @work_items.empty?(event.step_id)
        @events_by_request_id[event.request_id] = event
        @events.push(event.step_id, event)

        if can_run_event
          [create_next_event_work_item(event.step_id)]
        else
          []
        end
      end

      # turns the first event from the queue to the next work item to work on
      def create_next_event_work_item(step_id)
        event = @events.shift(step_id)
        queue = @step_queues[step_id]
        return unless event
        work = EventWorkItem.new(event.request_id, event.execution_plan_id, step_id, event.event, queue, @world.id)
        @work_items.push(step_id, work)
        work
      end

      # @yield [Concurrent.resolvable_future] in case the work item has an result future assigned
      # and deletes the tracked event
      def finish_event_result(work_item)
        return unless EventWorkItem === work_item
        if event = @events_by_request_id.delete(work_item.request_id)
          yield event.result if event.result
        end
      end
    end
  end
end
