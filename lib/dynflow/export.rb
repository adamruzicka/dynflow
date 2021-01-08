# frozen_string_literal: true

module Dynflow
  class Export
    attr_reader :world

    def initialize(world)
      @world = world
      @worlds = load_worlds
    end

    def prepare_execution_plan(plan)
      {
        uuid:              plan.id,
        label:             plan.label,
        state:             plan.state,
        result:            plan.result,
        started_at:        format_time(plan.started_at),
        ended_at:          format_time(plan.ended_at),
        execution_time:    plan.execution_time,
        real_time:         plan.real_time,
        execution_history: prepare_execution_history(plan.execution_history),
        plan_phase:        prepare_plan_phase(plan, plan.root_plan_step),
        run_phase:         prepare_flow(plan, plan.run_flow),
        finalize_phase:    prepare_flow(plan, plan.finalize_flow),
        steps:             plan.steps.values.map { |step| prepare_step(plan, step) },
        actions:           plan.actions.map { |action| prepare_action(action) },
        delay_record:      plan.delay_record && plan.delay_record.to_hash
      }
    end

    private

    def prepare_action(action)
      {
        :id => action.id,
        :label => action.label,
        :plan_step_id => action.plan_step_id,
        :run_step_id => action.run_step_id,
        :finalize_step_id => action.finalize_step_id,
        :input => action.input.to_hash,
        :output => action.output.to_hash
      }
    end

    def prepare_plan_phase(execution_plan, step)
      base = { :id => step.id }
      if step.children.any?
        base.merge!(
          :children => step.children.map do |step_id|
            step = execution_plan.steps[step_id]
            prepare_plan_phase(execution_plan, step)
          end
        )
      end
      base
    end

    def prepare_step(execution_plan, step)
      action = execution_plan.actions.find { |a| a.id == step.action_id }
      {
        id:             step.id,
        label:          action.label,
        phase:          step_phase(step),
        action_id:      step.action_id,
        state:          step.state,
        queue:          step.queue,
        started_at:     format_time(step.started_at),
        ended_at:       format_time(step.ended_at),
        real_time:      step.real_time,
        execution_time: step.execution_time,
      }
    end

    def step_phase(step)
      case step
      when Dynflow::ExecutionPlan::Steps::PlanStep
        'plan'
      when Dynflow::ExecutionPlan::Steps::RunStep
        'run'
      when Dynflow::ExecutionPlan::Steps::FinalizeStep
        'finalize'
      end
    end

    def prepare_execution_history(history)
      history.map do |entry|
        {
          event: entry.name,
          time: format_time(Time.at(entry.time)),
          world: {
            uuid: entry.world_id,
            meta: @worlds.fetch(entry.world_id, {}).fetch(:meta, {}).to_hash
          }
        }
      end
    end

    def prepare_delay_record(record)
      {
        start_at: format_time(record.start_at),
        start_before: format_time(record.start_before),
        frozen: record.frozen
      }
    end

    def load_worlds
      world.coordinator.find_worlds(false).reduce({}) do |acc, cur|
        acc.merge(cur.id => cur.to_hash)
      end
    end

    def prepare_flow(execution_plan, flow)
      case flow
      when Dynflow::Flows::Sequence
        { type: 'sequence', children: flow.flows.map { |flow| prepare_flow(execution_plan, flow) } }
      when Dynflow::Flows::Concurrence
        { type: 'concurrence', children: flow.flows.map { |flow| prepare_flow(execution_plan, flow) } }
      when Dynflow::Flows::Atom
        {:id => flow.step_id}
      end
    end

    def format_time(time)
      # ISO8601
      return unless time
      time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end
  end
end
