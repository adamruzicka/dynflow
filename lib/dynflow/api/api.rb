module Dynflow
  module Api
    class Api < Sinatra::Base
      helpers ApiHelpers

      def world
        settings.world
      end

      before do
        content_type :json
      end

      #
      # World collection routes
      #
      get('/worlds/?') do
        @worlds = world.coordinator.find_worlds
        result = @worlds.map { |world| world_to_hash world }
        MultiJson.dump(result)
      end

      get('/worlds/check') do
        @worlds = world.coordinator.find_worlds
        @validation_results = world.worlds_validity_check(params[:invalidate])
        result = @worlds.map { |world| world_to_hash world, @validation_results[world.id] }
        MultiJson.dump(result)
      end

      #
      # World member routes
      #
      post('/worlds/:id/check') do |id|
        filter = { :id => id }
        @world = world.coordinator.find_worlds(false, filter).first
        with_resource(@world) do
          @validation_results = world.worlds_validity_check(params[:invalidate], filter)
          MultiJson.dump(world_to_hash @world, @validation_results[@world.id])
        end
      end

      get('/worlds/:id') do |id|
        @world = world.coordinator.find_worlds(false, :id => id).first
        with_resource(@world) do
          MultiJson.dump(world_to_hash @world)
        end
      end

      #
      # Execution plan collection routes
      #
      get('/execution_plans/?') do
        raise NotImplementedError
      end

      get('/execution_plans/:execution_plan_id/actions/:action_id/sub_plans') do |execution_plan_id, action_id|
        raise NotImplementedError
      end

      get('/execution_plans/count') do
        raise NotImplementedError
      end

      #
      # Execution plan member routes
      #
      get('/execution_plans/:id') do |id|
        raise NotImplementedError
      end

      post('/execution_plans/:id/resume') do |id|
        raise NotImplementedError
      end

      post('/execution_plans/:id/cancel') do |id|
        raise NotImplementedError
      end

      #
      # Step member routes
      #
      post('/execution_plans/:id/steps/:step_id/skip') do |id, step_id|
        raise NotImplementedError
      end

      post('/execution_plans/:id/steps/:step_id/cancel') do |id, step_id|
        raise NotImplementedError
      end

      post('/execution_plans/:id/steps/:step_id/event') do |id, step_id|
        raise NotImplementedError
      end
    end
  end
end
