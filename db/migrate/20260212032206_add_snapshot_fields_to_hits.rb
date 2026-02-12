class AddSnapshotFieldsToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :fetch_status, :integer
    add_column :hits, :fetched_at, :datetime
    add_column :hits, :final_url, :text
    add_column :hits, :raw_html, :text
    add_column :hits, :plain_text, :text
    add_column :hits, :fetch_error, :text
  end
end
