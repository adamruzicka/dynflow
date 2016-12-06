module Dynflow
  class Middleware

    METHODS = [:delay, :plan, :run, :finalize, :plan_phase, :finalize_phase, :present, :revert, :revert_plan, :revert_run]

    require 'dynflow/middleware/register'
    require 'dynflow/middleware/world'
    require 'dynflow/middleware/resolver'
    require 'dynflow/middleware/stack'
    require 'dynflow/middleware/common/transaction'
    require 'dynflow/middleware/common/singleton'

    include Algebrick::TypeCheck

    def initialize(stack)
      @stack = Type! stack, Stack
    end

    # call `pass` to get deeper with the call
    def pass(*args)
      @stack.pass(*args)
    end

    # to get the action object
    def action
      @stack.action or raise "the action is not available"
    end

    def delay(*args)
      pass(*args)
    end

    def run(*args)
      pass(*args)
    end

    def plan(*args)
      pass(*args)
    end

    def finalize(*args)
      pass(*args)
    end

    def plan_phase(*args)
      pass(*args)
    end

    def finalize_phase(*args)
      pass(*args)
    end

    def revert_run(*args)
      pass(*args)
    end

    def revert_plan(*args)
      pass(*args)
    end

    def revert(*args)
      pass(*args)
    end

    def present
      pass
    end

    def hook(*args)
      pass(*args)
    end
  end
end
