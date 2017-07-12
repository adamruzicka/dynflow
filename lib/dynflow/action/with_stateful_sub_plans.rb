module Dynflow
  module Action
    module WithStatefulSubPlans

      def spawn_plans
        sub_plans = create_sub_plans
        sub_plans = Array[sub_plans] unless sub_plans.is_a? Array
        wait_for_sub_plans sub_plans
      end

     
    end
  end
end
