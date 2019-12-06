# frozen_string_literal: true
module Dynflow
  class Director
    class ExecutionPlanManager
      include Algebrick::TypeCheck
      include Algebrick::Matching

      attr_reader :execution_plan, :future

      def initialize(world, execution_plan, future, director)
        @world                 = Type! world, World
        @execution_plan        = Type! execution_plan, ExecutionPlan
        @future                = Type! future, Concurrent::Promises::ResolvableFuture
        @running_steps_manager = RunningStepsManager.new(world)
        @director = director

        unless [:planned, :paused].include? execution_plan.state
          raise "execution_plan is not in pending or paused state, it's #{execution_plan.state}"
        end
        execution_plan.update_state(:running)
      end

      def start
        raise "The future was already set" if @future.resolved?
        start_run or start_finalize or no_work
      end

      def restart
        @running_steps_manager.restart
        @run_manager = nil
        @finalize_manager = nil
        start
      end

      def prepare_next_step(step, done, item_future)
        StepWorkItem.new(execution_plan.id, step, step.queue, @world.id).tap do |work|
          @running_steps_manager.add(step, work, done, item_future)
        end
      end

      def work_finished(work)
        case work
        when StepWorkItem
          step = work.step
          update_steps([step])
          @running_steps_manager.done(step)
        when FinalizeWorkItem
          if work.finalize_steps_data
            steps = work.finalize_steps_data.map do |step_data|
              Serializable.from_hash(step_data, execution_plan.id, @world)
            end
            update_steps(steps)
          end
          raise "Finalize work item without @finalize_manager ready" unless @finalize_manager
          @finalize_manager = :done
          no_work
        else
          raise "Unexpected work #{work}"
        end
      end

      def event(event)
        Type! event, Event
        unless event.execution_plan_id == @execution_plan.id
          raise "event #{event.inspect} doesn't belong to plan #{@execution_plan.id}"
        end
        @running_steps_manager.next(event.step_id) do |f|
          f.then { @director.executor.handle_work(@running_steps_manager.event(event)) }
           .on_rejection do |reason|
            return if reason == :restart
            if reason == :termination
              w.event.result.reject UnprocessableEvent.new('dropping due to termination')
            else
              @world.logger.debug "step #{step.execution_plan_id}:#{step.id} dropping event #{event.request_id}/#{event}"
              if event.result
                event.result.reject UnprocessableEvent.new("Message dropped").tap { |e| e.set_backtrace(caller) }
              end
            end
          end
        end
      end

      def done?
        (!@run_manager || @run_manager.fulfilled?) && (!@finalize_manager || @finalize_manager == :done)
      end

      def terminate
        @running_steps_manager.terminate
      end

      private

      def update_steps(steps)
        steps.each { |step| execution_plan.steps[step.id] = step }
      end

      def no_work
        raise "No work but not done" unless done?
      end

      def start_run
        return if execution_plan.run_flow.empty?
        raise 'run phase already started' if @run_manager
        manager = FlowManager.new(execution_plan, execution_plan.run_flow)
        @run_manager = manager.promise_flow(execution_plan.run_flow) do |done, step_id|
          step = execution_plan.steps[step_id]
          if [:stopped, :skipped].include? step.state
            done.fulfill true
            return
          end
          work_item = prepare_next_step(step, done, Concurrent::Promises.resolvable_future)
          @director.executor.handle_work(work_item)
        end
        @run_manager.then { @director.executor.handle_work start_finalize }
      end

      def start_finalize
        return if execution_plan.finalize_flow.empty?
        raise 'finalize phase already started' if @finalize_manager
        @finalize_manager = :started
        [FinalizeWorkItem.new(execution_plan.id, execution_plan.finalize_steps.first.queue, @world.id)]
      end
    end
  end
end
