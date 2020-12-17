class CreateKeys < ActiveRecord::Migration[6.0]
  def change
    create_table :keys do |t|
    	t.references :user, null: false, foreign_key: true
		t.text :key, :integer, limit: 8
		t.timestamps
    end
  end
end
