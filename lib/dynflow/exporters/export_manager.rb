module Dynflow
  module Exporters
    class ExportManager

      def initialize(world, exporter, io, options = {})
        @world    = world
        @exporter = exporter
        @options  = options
        @io       = io
        @db_batch_size = options.fetch(:db_batch_size, 50)
        @queue    = {}
        @wrap_before, @separator, @wrap_after = @exporter.brackets
      end

      def add(plans)
        plans = [plans] unless plans.kind_of? Array
        plans.each do |plan|
          if plan.is_a? String
            @queue[plan] = nil
          else
            @queue[plan.id] = plan
          end
        end
        self
      end

      # Stream all the entries into one file
      def export_collection
        @io.write(@wrap_before) unless @wrap_before.nil?
        each do |uuid, content, last|
          yield uuid if block_given?
          @io.write(content)
          @io.write(@separator) if @separator && !last
        end
        @io.write(@wrap_after) unless @wrap_after.nil?
      end

      private

      def each(&block)
        last_uuid = @queue.keys.last
        @queue.each_slice(@db_batch_size) do |batch|
          resolve_ids(batch).each do |uuid, plan|
            yield [uuid, @exporter.export(plan), uuid == last_uuid]
          end
        end
      end


      # Selects the entries from the provided queue whose value is nil
      # Loads execution plans for those ids from the database
      def resolve_ids(batch)
        unloaded, loaded = batch.partition { |_key, value| value.nil? }
        ids = unloaded.map(&:first)
        return batch if ids.empty?
        resolved = @world.persistence.find_execution_plans(:filters => { :uuid => ids }).map do |plan|
          [plan.id, plan]
        end
        loaded + resolved
      end
    end
  end
end
