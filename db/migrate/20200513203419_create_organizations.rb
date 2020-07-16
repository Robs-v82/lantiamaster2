class CreateOrganizations < ActiveRecord::Migration[6.0]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :acronym
      t.boolean :legal
      # t.references :division, null: false, foreign_key: true
      t.timestamps
    end

    create_table :divisions_organizations, id: false do |t|
      t.belongs_to :division
      t.belongs_to :organization
    end
  end
end
