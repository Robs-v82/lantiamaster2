class AddYearsToQuarters < ActiveRecord::Migration[6.0]
  def change
    add_reference :quarters, :year, foreign_key: true
  end
end
