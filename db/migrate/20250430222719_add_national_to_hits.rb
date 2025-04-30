class AddNationalToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :national, :boolean
  end
end
