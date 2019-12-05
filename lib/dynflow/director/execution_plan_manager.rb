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
        start_run or start_finalize or finish
      end

      def restart
        @run_manager = nil
        @finalize_manager = nil
        start
      end

      def prepare_next_step(step, done)
        StepWorkItem.new(execution_plan.id, step, step.queue, @world.id).tap do |work|
          @running_steps_manager.add(step, work, done)
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
          finish
        else
          raise "Unexpected work #{work}"
        end
      end

      def event(event)
        Type! event, Event
        unless event.execution_plan_id == @execution_plan.id
          raise "event #{event.inspect} doesn't belong to plan #{@execution_plan.id}"
        end
        @director.executor.handle_work(@running_steps_manager.event(event))
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

      def compute_next_from_step(step)
        raise "run manager not set" unless @run_manager
        raise "run manager already done" if @run_manager.fulfilled?

        next_steps = @run_manager.what_is_next(step)
        if @run_manager.fulfilled?
          start_finalize or finish
        else
          next_steps.map { |s| prepare_next_step(s) }
        end
      end

      def no_work
        raise "No work but not done" unless done?
        []
      end

      def start_run
        return if execution_plan.run_flow.empty?
        raise 'run phase already started' if @run_manager
        manager = FlowManager.new(execution_plan, execution_plan.run_flow)
        @run_manager = manager.promise_flow(execution_plan.run_flow) do |done, step_id|
          puts "EXECUTING #{step_id}"
          step = execution_plan.steps[step_id]
          work_item = prepare_next_step(step, done)
          @director.executor.handle_work(work_item)
        end
        @run_manager.then { @director.executor.handle_work start_finalize }
        # @run_manager.start.map { |s| prepare_next_step(s) }.tap { |a| raise if a.empty? }
      end

      def start_finalize
        return if execution_plan.finalize_flow.empty?
        raise 'finalize phase already started' if @finalize_manager
        @finalize_manager = :started
        [FinalizeWorkItem.new(execution_plan.id, execution_plan.finalize_steps.first.queue, @world.id)]
      end

      def finish
        return no_work
      end

    end
  end
end
