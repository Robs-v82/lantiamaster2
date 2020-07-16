class AddVariablesToKilling < ActiveRecord::Migration[6.0]
  def change
  	add_column :killings, :legacy_number, :integer
  	add_column :killings, :aggresor_count, :integer
  	add_column :killings, :kidnapped_count, :integer
  	add_column :killings, :killer_vehicle_count, :integer
  	add_column :killings, :car_chase, :boolean
  	add_column :killings, :shooting_among_criminals, :boolean
  	add_column :killings, :message, :string
  end
end
