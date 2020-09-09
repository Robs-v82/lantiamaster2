class AddLegacyToLeads < ActiveRecord::Migration[6.0]
  def change
    add_column :leads, :legacy_id, :integer
  end
end
