class AddReportToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :report, :string
  end
end
