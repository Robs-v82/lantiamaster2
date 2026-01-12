class AddSubscriptionStartedAtToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :subscription_started_at, :datetime
  end
end
