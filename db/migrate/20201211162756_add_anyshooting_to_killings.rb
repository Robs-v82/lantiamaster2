class AddAnyshootingToKillings < ActiveRecord::Migration[6.0]
  def change
    add_column :killings, :any_shooting, :boolean
  end
end
