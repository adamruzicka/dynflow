require 'sourcify'
module Dynflow
  class StateTransition
    attr_reader :from, :to, :condition, :callback
    def initialize(from, to, condition, callback)
      @from = from
      @to = to
      @condition = condition
      @callback = callback
    end

    def can_transition?
      @condition.nil? || (yield @condition)
    end
  end

  module StateMachineClassMethods
    attr_reader :state_transitions, :initial_state, :final_states

    def state(name, options = {})
      @states ||= []
      @states << name
      @final_states ||= []
      @final_states << name if options[:final]
      @initial_state = name if options[:initial]
    end

    def add_transition(from, to, condition, callback)
      # action_logger.debug "loading transition #{from} -> #{to}"
      @state_transitions ||= {}
      @state_transitions[from] ||= {}
      @state_transitions[from][to] ||= []
      @state_transitions[from][to] << StateTransition.new(from, to, condition, callback)
    end

    def transition(from, to, options = {}, &block)
      add_transition(from, to, options[:condition], block)
    end

    def plantuml
      parts = []
      parts << '@startuml'
      parts << "[*] --> #{@initial_state}"
      parts.concat(@states.map { |state| "state #{state}" })
      
      transitions = @state_transitions.values.map(&:values).flatten.map do |transition|
        condition = transition.condition.nil? ? nil : %Q( : "#{transition.condition.to_source.gsub('"', "'")}")
        direction = transition.from == transition.to ? 'down' : ''
        %Q(#{transition.from} -#{direction}-> #{transition.to} #{condition})
      end
      parts.concat(transitions)
      
      parts.concat(@final_states.map { |state| "#{state} --> [*]" })
      parts << '@enduml'
      parts.join("\n")
    end
  end

  module StateMachineInstanceMethods
    def possible_transitions(from, event, action)
      self.class.state_transitions[from].values.flatten.select do |transition|
        transition.can_transition? { |block| instance_eval(&block) }
      end
    end

    def can_end?(state)
      self.class.final_states.include? state
    end

    def init!
      output[:fsm] = { :state => self.class.initial_state }
    end

    def current_state
      fsm_control[:state]
    end

    def run(event = nil)
      @event = event
      init! if fsm_control.nil?
      until output[:fsm][:finish] do
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
            instance_eval(@event, &transition.callback)
          end
          # suspend unless output[:fsm][:finish]
        end
      end
    end

    def can_finish?
      can_end?(output[:fsm][:transitioning].values.first)
    end
    
    private

    def finish
      raise "Attempted to finish in non-final state #{current_state}" unless can_finish?
      output[:fsm][:finish] = true
    end

    def with_transition_tracking(transition, &block)
      output[:fsm][:transitioning] = { transition.from => transition.to }
      yield
    ensure
      output[:fsm][:transitioning] = nil
      output[:fsm][:state] = transition.to
    end
    
    def fsm_control
      output[:fsm]
    end
  end
end
