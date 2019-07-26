module Dynflow
  module Executors
    module Sidekiq
      module OrchestratorJobs
        # handles resposnes about finished work form the workers
        # or some event to handle on orchestrator side
        class WorkerDone < InternalJobBase
          sidekiq_options queue: :dynflow_orchestrator

          # @param request_envelope [Dispatcher::Request] - request to handle on orchestrator side
          #   usually to start new execution or to pass some event
          def perform(work_item)
            Dynflow.process_world.executor.core.ask!([:work_finished, work_item])
          end
        end

        class HandlePersistenceError < InternalJobBase
          sidekiq_options queue: :dynflow_orchestrator

          # @param request_envelope [Dispatcher::Request] - request to handle on orchestrator side
          #   usually to start new execution or to pass some event
          def perform(error, work_item)
            Dynflow.process_world.executor.core.ask!([:handle_persistence_error, error, work_item])
          end
        end

        class FinishStartup < InternalJobBase
          sidekiq_options queue: :dynflow_orchestrator

          # @param request_envelope [Dispatcher::Request] - request to handle on orchestrator side
          #   usually to start new execution or to pass some event
          def perform
            Dynflow.process_world.executor.core.ask!([:finish_startup])
          end
        end
      end
    end
  end
end
