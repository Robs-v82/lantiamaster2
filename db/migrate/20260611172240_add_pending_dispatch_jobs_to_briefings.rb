class AddPendingDispatchJobsToBriefings < ActiveRecord::Migration[6.0]
  def change
    add_column :briefings, :pending_dispatch_jobs, :integer, default: 0
  end
end
