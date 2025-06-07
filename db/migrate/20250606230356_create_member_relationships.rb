class CreateMemberRelationships < ActiveRecord::Migration[6.0]
  def change
    create_table :member_relationships do |t|
      t.references :member_a, null: false, foreign_key: { to_table: :members }
      t.references :member_b, null: false, foreign_key: { to_table: :members }
      t.string :role_a, null: false
      t.string :role_b, null: false
      t.text :notes

      t.timestamps
    end

    add_index :member_relationships, [:member_a_id, :member_b_id, :role_a, :role_b], unique: true, name: 'index_member_relationships_uniqueness'
  end
end

