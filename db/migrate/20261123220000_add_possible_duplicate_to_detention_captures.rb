class AddPossibleDuplicateToDetentionCaptures < ActiveRecord::Migration[6.0]
  def change
    add_column :detention_captures, :possible_duplicate, :boolean, default: false, null: false
    add_column :detention_captures, :possible_duplicate_note, :text
  end
end
