class AddStartAndEndDateToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :start_date, :date
    add_column :members, :end_date, :date
  end
end
