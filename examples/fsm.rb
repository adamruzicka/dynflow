#!/usr/bin/env ruby

require_relative 'example_helper'

module FSM
  class StatefulAction < ::Dynflow::Action
    extend  ::Dynflow::StateMachineClassMethods
    include ::Dynflow::StateMachineInstanceMethods

    define_states do
      state 'initial', :initial => true
      state 'testing'
    end

    define_transitions do
      transition '
    end

    def set_states
      add_state 'initial', :initial => true
      add_state 'counting'
      add_state 'final', :final => true
      self.class.load_states
    end
    
    def set_transitions
      state_transition 'initial', 'counting' do
        output[:counter] = 0
        suspended_action << nil
      end

      state_transition 'counting', 'counting', :condition => ->(*args) { !stopping_condition } do
        output[:counter] += 1
        suspended_action << nil
      end

      state_transition 'counting', 'final', :condition => ->(*args) { stopping_condition } do
        puts "Ending"
        finish
      end
    end

    def stopping_condition
      output[:counter] >= 5
    end
  end
end

if $0 == __FILE__
  ExampleHelper.world.action_logger.level = Logger::DEBUG
  ExampleHelper.world.trigger(FSM::StatefulAction, :x => 5)
  ExampleHelper.run_web_console
end
