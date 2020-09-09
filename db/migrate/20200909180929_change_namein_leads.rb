class ChangeNameinLeads < ActiveRecord::Migration[6.0]
  def change
  	rename_column :leads, :type, :category
  end
end
