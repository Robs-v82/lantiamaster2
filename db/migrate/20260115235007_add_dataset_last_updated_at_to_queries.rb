class AddDatasetLastUpdatedAtToQueries < ActiveRecord::Migration[6.0]
  def change
    add_column :queries, :dataset_last_updated_at, :datetime
  end
end
