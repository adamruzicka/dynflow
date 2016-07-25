module Dynflow
  module Action::Rescue

    Strategy = Algebrick.type do
      variants Skip = atom, Pause = atom, Revert = atom, Fail = atom
    end

    SuggestedStrategy = Algebrick.type do
      fields! action:   Action,
              strategy: Strategy
    end

    # What strategy should be used for rescuing from error in
    # the action or its sub actions
    #
    # @return Strategy
    #
    # When determining the strategy, the algorithm starts from the
    # entry action that by default takes the strategy from #rescue_strategy_for_self
    # and #rescue_strategy_for_planned_actions and combines them together.
    def rescue_strategy
      suggested_strategies = []

      if self.steps.compact.any? { |step| step.state == :error }
        suggested_strategies << SuggestedStrategy[self, rescue_strategy_for_self]
      end

      self.planned_actions.each do |planned_action|
        rescue_strategy = rescue_strategy_for_planned_action(planned_action)
        next unless rescue_strategy # ignore actions that have no say in the rescue strategy
        suggested_strategies << SuggestedStrategy[planned_action, rescue_strategy]
      end

      combine_suggested_strategies(suggested_strategies)
    end

    # Override when another strategy should be used for rescuing from
    # error on the action
    def rescue_strategy_for_self
      return Pause
    end

    # Override when the action should override the rescue
    # strategy of an action it planned
    def rescue_strategy_for_planned_action(action)
      action.rescue_strategy
    end

    # Override when different approach should be taken for combining
    # the suggested strategies
    def combine_suggested_strategies(suggested_strategies)
      return Skip if suggested_strategies.empty?

      counts = suggested_strategies.map(&:strategy).reduce({}) do |acc, cur|
        acc.merge(cur => acc.fetch(cur, 0) + 1)
      end
      agreement = [Fail, Pause, Revert, Skip].find { |key| counts[key] == suggested_strategies.count }

      if agreement
        agreement
      else
        Pause
      end
    end
  end
end

