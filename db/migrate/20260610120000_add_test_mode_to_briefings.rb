class AddTestModeToBriefings < ActiveRecord::Migration[6.0]
  def change
    add_column :briefings, :test_mode, :boolean, default: true, comment: "true = enviar a @lantiaintelligence.com solo, false = enviar a todos"
    add_column :briefings, :test_emails, :text, comment: "JSON array de emails que recibirán en modo test"

    add_index :briefings, :test_mode
  end
end
