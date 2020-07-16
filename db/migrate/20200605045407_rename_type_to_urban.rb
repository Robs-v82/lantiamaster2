class RenameTypeToUrban < ActiveRecord::Migration[6.0]
  def change
  	rename_column :towns, :type, :urban
  end
end
