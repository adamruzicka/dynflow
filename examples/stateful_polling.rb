#!/usr/bin/env ruby

require_relative 'example_helper'

class StatefulPollingAction < ::Dynflow::Action
  extend  ::Dynflow::StateMachineClassMethods
  include ::Dynflow::StateMachineInstanceMethods

  state 'initial', :initial => true
  state 'waiting'
  state 'polling'
  state 'timed_out', :final => true
  state 'failed', :final => true
  state 'final', :final => true

  transition 'initial', 'waiting' do
    self.external_task = invoke_external_task
    suspend_and_ping
  end

  transition 'waiting', 'polling', :condition => proc { |event| event == Poll } do
    poll_external_task_with_rescue
  end

  transition 'polling', 'polling', :condition => proc { } do
    action_logger.warn("Polling failed, attempt no. #{poll_attempts[:failed]}, retrying in #{poll_interval}")
    action_logger.warn(error)
  end

  transition 'polling', 'failed', :condition => proc { poll_attempts[:failed] >= poll_max_retries } do |error|
    raise error
  end

  transition 'polling', 'final', :condition => :done? do
    on_finish
  end

  transition 'polling', 'waiting', :condition => proc { !done? } do
    poll_attempts[:failed] = 0
    suspend
  end

  transition 'waiting', 'timed_out', :condition => proc { |event| event == Timeout } do
    process_timeout
    suspend
  end

  def poll_external_task
    raise NotImplementedError
  end

  def done?
    raise NotImplementedError
  end

  def invoke_external_task
    raise NotImplementedError
  end

  def on_finish
  end

  def poll_external_task_with_rescue
    poll_attempts[:total] += 1
    self.external_task = poll_external_task
  rescue => error
    poll_attempts[:failed] += 1
    @event = error
  end

  # External task data. It should return nil when the task has not
  # been triggered yet.
  def external_task
    output[:task]
  end

  def external_task=(external_task_data)
    output[:task] = external_task_data
  end

  def poll_attempts
    output[:poll_attempts] ||= { total: 0, failed: 0 }
  end

  def suspend_and_ping
    suspend { |suspended_action| world.clock.ping suspended_action, poll_interval, Poll }
  end
end

if $0 == __FILE__
  ExampleHelper.world.action_logger.level = Logger::DEBUG
  ExampleHelper.world.trigger(StatefulPollingAction)
  ExampleHelper.run_web_console
end
