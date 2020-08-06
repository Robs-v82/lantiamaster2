class AddQuartersToMonths < ActiveRecord::Migration[6.0]
  def change
    add_reference :months, :quarter, null: false, foreign_key: true
  end
end
