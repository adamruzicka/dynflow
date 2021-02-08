module Dynflow
  module ActiveJob
    loader = Zeitwerk::Loader.new
    loader.push_dir("#{__dir__}/active_job", namespace: ::Dynflow::ActiveJob)
    loader.log!
    loader.setup
    loader.eager_load
  end
end