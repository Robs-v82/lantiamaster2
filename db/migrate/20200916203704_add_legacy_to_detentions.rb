class AddLegacyToDetentions < ActiveRecord::Migration[6.0]
  def change
    add_column :detentions, :legacy_id, :integer
  end
end
