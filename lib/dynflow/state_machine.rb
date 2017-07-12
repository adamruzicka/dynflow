module Dynflow
  class StateTransition
    attr_reader :from, :to
    def initialize(from, to, condition, callback)
      @from = from
      @to = to
      @condition = condition
      @callback = callback
    end

    def can_transition?(action, event)
      @condition.nil? || @condition.call(action, event)
    end

    def transition(action, event)
      unless @callback.nil?
        @callback.call(action, event)
      end
    end
  end

  module StateMachineClassMethods
    def define_states(&block)
      @block = block
    end

    def load_states
      @block.call
    end

    def state(name, options = {})
      @states ||= []
      @states << name
    end
  end

  module StateMachineInstanceMethods
    def state_transition(from, to, options = {}, &block)
      add_transition(from, to, options[:condition], block) if current_state == from
    end
    
    def initial_state
      @initial_state
    end

    def possible_transitions(from, event, action)
      @state_transitions[from].values.flatten.select { |transition| transition.can_transition?(action, event) }
    end

    def can_end?(state)
      @final_states.include? state
    end

    def init!
      output[:fsm] = { :state => initial_state }
    end

    def current_state
      fsm_control[:state]
    end

    def run(event = nil)
      set_states
      init! if fsm_control.nil?
      set_transitions
      to = possible_transitions current_state, event, self
      if to.empty?
        if can_end?(current_state)
          finish
        else
          raise "Cannot transition anywhere from #{current_state}"
        end
      elsif to.count > 1
        raise "Cannot deterministically transition anywhere from #{current_state}"
      else
        transition = to.first
        with_transition_tracking(transition) do
          transition.transition(self, event)
        end
        suspend unless output[:fsm][:finish]
      end
    end

    def can_finish?
      can_end?(output[:fsm][:transitioning].values.first)
    end
    
    private

    def set_states
      fsm_state 'initial', :initial => true, :final => true
    end

    def set_transitions
      raise NotImplementedError
    end

    def finish
      raise "Attempted to finish in non-final state #{current_state}" unless can_finish?
      output[:fsm][:finish] = true
    end

    def add_state(name, options = {})
      @states ||= []
      @states << name
      @final_states ||= []
      @final_states << name if options[:final]
      @initial_state = name if options[:initial]
    end

    def add_transition(from, to, condition, callback)
      action_logger.debug "loading transition #{from} -> #{to}"
      @state_transitions ||= {}
      @state_transitions[from] ||= {}
      @state_transitions[from][to] ||= []
      @state_transitions[from][to] << StateTransition.new(from, to, condition, callback)
    end

    def with_transition_tracking(transition, &block)
      output[:fsm][:transitioning] = { transition.from => transition.to }
      yield
      output[:fsm][:transitioning] = nil
      output[:fsm][:state] = transition.to
    end
    
    def fsm_control
      output[:fsm]
    end
  end
end
