module Dynflow
  module Action
    module WithStatefulSubPlans

      extend ::Dynflow::StateMachineClassMethods
      include ::Dynflow::StateMachineInstanceMethods
      
      state 'initial', :initial => true
      state 'can_spawn_more'
      state 'waiting_for_results'
      state 'final'

      transition 'initial', 'final'

      def spawn_plans
        sub_plans = create_sub_plans
        sub_plans = Array[sub_plans] unless sub_plans.is_a? Array
        wait_for_sub_plans sub_plans
      end

     
    end
  end
end
