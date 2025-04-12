class AddLegacyIdToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :legacy_id, :string
  end
end
