class AddDeliveredEmailsToBriefings < ActiveRecord::Migration[6.0]
  def change
    add_column :briefings, :delivered_emails, :text, comment: "JSON array de emails que recibieron el correo exitosamente"
  end
end
