class AddOrganizationToDetentionCaptures < ActiveRecord::Migration[6.0]
  def change
    add_reference :detention_captures, :organization, null: true, foreign_key: { on_delete: :nullify }
  end
end
