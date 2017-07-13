#!/usr/bin/env ruby

require_relative 'example_helper'

module FSM
  class StatefulAction < ::Dynflow::Action
    extend  ::Dynflow::StateMachineClassMethods
    include ::Dynflow::StateMachineInstanceMethods

      state 'initial', :initial => true
      state 'counting'
      state 'final', :final => true

      transition 'initial', 'counting' do
        output[:counter] = 0
      end

      transition 'counting', 'counting', :condition => proc { |event| !stopping_condition } do
        output[:counter] += 1
      end

      transition 'counting', 'final', :condition => :stopping_condition do
        finish
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
