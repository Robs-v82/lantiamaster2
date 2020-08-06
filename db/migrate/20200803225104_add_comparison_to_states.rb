class AddComparisonToStates < ActiveRecord::Migration[6.0]
  def change
    add_column :states, :comparison, :text
  end
end
