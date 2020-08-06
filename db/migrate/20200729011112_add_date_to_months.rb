class AddDateToMonths < ActiveRecord::Migration[6.0]
  def change
    add_column :months, :first_day, :datetime
  end
end
