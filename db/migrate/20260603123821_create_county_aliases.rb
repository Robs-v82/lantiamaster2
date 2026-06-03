class CreateCountyAliases < ActiveRecord::Migration[6.0]
  def change
    create_table :county_aliases do |t|
      t.references :county, null: false, foreign_key: true
      t.string :alias_name, null: false, index: true
      t.string :alias_type, default: 'common_name'
      # alias_type: 'common_name' (Cancún), 'alternative' (variaciones), etc.

      t.timestamps
    end

    add_index :county_aliases, [:county_id, :alias_name], unique: true
  end
end
