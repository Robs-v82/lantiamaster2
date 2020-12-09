class AddShootingToKillings < ActiveRecord::Migration[6.0]
  def change
    add_column :killings, :shooting, :boolean
  end
end
