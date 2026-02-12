class AddBackupTrackingToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :backup_status, :string
    add_column :hits, :backup_source, :string
    add_column :hits, :backup_version, :integer
    add_column :hits, :backup_checked_at, :datetime
    change_column_default :hits, :backup_version, 0
  end
end
