class AddFirstDayToQuarters < ActiveRecord::Migration[6.0]
  def change
    add_column :quarters, :first_day, :datetime
  end
end
