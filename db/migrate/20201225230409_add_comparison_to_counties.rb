class AddComparisonToCounties < ActiveRecord::Migration[6.0]
  def change
    add_column :counties, :comparison, :text
  end
end
