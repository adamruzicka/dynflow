# frozen_string_literal: true
module Dynflow
  module Executors
    module Abstract
      class Core < Actor
        attr_reader :logger

        def initialize(world, heartbeat_interval, queues_options)
          @logger         = world.logger
          @world          = Type! world, World
          @pools          = {}
          @terminated     = nil
          @director       = Director.new(@world)
          @heartbeat_interval = heartbeat_interval
          @queues_options = queues_options
          @flow_managers = {}
          @running_steps = {}

          schedule_heartbeat
        end

        def handle_execution(execution_plan_id, finished)
          if terminating?
            raise Dynflow::Error,
                  "cannot accept execution_plan_id:#{execution_plan_id} core is terminating"
          end

          execution_plan = @world.persistence.load_execution_plan(execution_plan_id)
          manager = ::Dynflow::Director::FlowManager.new(execution_plan, execution_plan.run_flow)
          @flow_managers[execution_plan_id] = manager
          manager.promise_flow(execution_plan.run_flow) do |done, step_id|
            puts "EXECUTING #{step_id}"
            @running_steps[execution_plan_id] = {}
            @running_steps[execution_plan_id][step_id] = done
            execution_plan.update_state(:running)
            step = execution_plan.steps[step_id]
            handle_work(::Dynflow::Director::StepWorkItem.new(execution_plan.id, step, step.queue, @world.id))
          end
          # handle_work(@director.start_execution(execution_plan_id, finished))
        end

        def handle_event(event)
          Type! event, Director::Event
          if terminating?
            raise Dynflow::Error,
                  "cannot accept event: #{event} core is terminating"
          end
          execution_plan = @world.persistence.load_execution_plan(event.execution_plan_id)
          step = execution_plan.steps[event.step_id]
          handle_work(::Dynflow::Director::EventWorkItem.new(event.request_id, event.execution_plan_id, step, event.event, step.queue, @world.id))
        end

        def plan_events(delayed_events)
          delayed_events.each do |event|
            @world.plan_event(event.execution_plan_id, event.step_id, event.event, event.time)
          end
        end

        def work_finished(work, delayed_events = nil)
          return if work.step.state == :suspended
          done = @running_steps[work.execution_plan_id][work.step.id]
          case work
          when StepWorkItem
            if work.state == :success
              done.fulfill true
            else
              done.reject false
            end
          when FinalizeWorkItem

          end
          plan_events(delayed_events) if delayed_events
        end

        def handle_persistence_error(error, work = nil)
          logger.error "PersistenceError in executor"
          logger.error error
          @director.work_failed(work) if work
          if error.is_a? Errors::FatalPersistenceError
            logger.fatal "Terminating"
            @world.terminate
          end
        end

        def start_termination(*args)
          logger.info 'shutting down Core ...'
          super
        end

        def finish_termination
          @director.terminate
          logger.info '... Dynflow core terminated.'
          super()
        end

        def dead_letter_routing
          @world.dead_letter_handler
        end

        def execution_status(execution_plan_id = nil)
          {}
        end

        def heartbeat
          @logger.debug('Executor heartbeat')
          record = @world.coordinator.find_records(:id => @world.id,
                                                   :class => ['Dynflow::Coordinator::ExecutorWorld', 'Dynflow::Coordinator::ClientWorld']).first
          unless record
            logger.error(%{Executor's world record for #{@world.id} missing: terminating})
            @world.terminate
            return
          end

          record.data[:meta].update(:last_seen => Dynflow::Dispatcher::ClientDispatcher::PingCache.format_time)
          @world.coordinator.update_record(record)
          schedule_heartbeat
        end

        private

        def suggest_queue(work_item)
          queue = work_item.queue
          unless @queues_options.key?(queue)
            logger.debug("Pool is not available for queue #{queue}, falling back to #{fallback_queue}")
            queue = fallback_queue
          end
          queue
        end

        def fallback_queue
          :default
        end

        def schedule_heartbeat
          @world.clock.ping(self, @heartbeat_interval, :heartbeat)
        end

        def on_message(message)
          super
        rescue Errors::PersistenceError => e
          handle_persistence_error(e)
        end

        def handle_work(work_items)
          puts "HANDLING #{work_items}"
          return if terminating?
          return if work_items.nil?
          puts "REALLY HANDLING #{work_items}"
          work_items = [work_items] if work_items.is_a? Director::WorkItem
          work_items.all? { |i| Type! i, Director::WorkItem }
          feed_pool(work_items)
        end

        def feed_pool(work_items)
          raise NotImplementedError
        end
      end
    end
  end
end
