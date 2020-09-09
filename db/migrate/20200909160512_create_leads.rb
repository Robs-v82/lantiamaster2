class CreateLeads < ActiveRecord::Migration[6.0]
  def change
    create_table :leads do |t|
      t.string :type
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end
  end
end
