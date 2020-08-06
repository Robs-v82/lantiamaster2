class CreateYears < ActiveRecord::Migration[6.0]
  def change
    create_table :years do |t|
      t.string :name
      t.datetime :first_day

      t.timestamps
    end
  end
end
