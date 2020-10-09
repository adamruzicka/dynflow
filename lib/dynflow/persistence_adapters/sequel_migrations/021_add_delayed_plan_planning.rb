# frozen_string_literal: true
Sequel.migration do
  change do
    alter_table(:dynflow_delayed_plans) do
      add_column :planning, :boolean, :default => false
    end
    self[:dynflow_delayed_plans].update(:planning => false)
  end
end
