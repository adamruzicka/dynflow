# frozen_string_literal: true
module Dynflow
  module Executors

    require 'dynflow/executors/parallel'

    class << self
      def run_user_code
        # Always acquire a connection from the DB pool, even if it may not be
        # needed
        ::ActiveRecord::Base.connection_pool.with_connection do |_conn|
          yield
        end
      ensure
        ::Logging.mdc.clear if defined? ::Logging
      end

      private

      def active_record_open_transactions
        active_record_active_connection&.open_transactions || 0
      end

      def active_record_active_connection
        return unless defined?(::ActiveRecord) && ::ActiveRecord::Base.connected?
        # #active_connection? returns the connection if already established or nil
        ::ActiveRecord::Base.connection_pool.active_connection?
      end

      def active_record_connected?
        !!active_record_active_connection
      end
    end
  end
end
