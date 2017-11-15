module Dynflow
  module Api
    module ApiHelpers
      def world_to_hash(world, validation_result = nil)
        hash = {
                :id => world.id,
                :meta => world.meta,
                :executor => world.is_a?(Dynflow::Coordinator::ExecutorWorld),
               }
        if validation_result
          hash.merge(:valid => validation_result)
        else
          hash
        end
      end

      def with_resource(resource)
        if resource.nil?
          body MultiJson.dump(body)
          halt status
        else
          yield
        end
      end
    end
  end
end
