class AddDestionationToCounties < ActiveRecord::Migration[6.0]
  def change
    add_column :counties, :destination, :boolean
  end
end
