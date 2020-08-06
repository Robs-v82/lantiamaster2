class AddMonthsToEvents < ActiveRecord::Migration[6.0]
  def change
    add_reference :events, :month, foreign_key: true
  end
end
