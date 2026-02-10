class AddCriminalRoleToMembers < ActiveRecord::Migration[6.0]
  ALLOWED = [
    "Líder",
    "Miembro",
    "Socio",
    "Autoridad vinculada",
    "Servicios lícitos",
    "Familiar/allegado",
    "Autoridad expuesta"
  ].freeze

  def up
    add_column :members, :criminal_role, :string, null: true

    # Permite NULL, pero si hay valor, obliga a que esté en el set permitido
    execute <<~SQL
      ALTER TABLE members
      ADD CONSTRAINT members_criminal_role_check
      CHECK (criminal_role IS NULL OR criminal_role IN (#{ALLOWED.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")}));
    SQL

    add_index :members, :criminal_role
  end

  def down
    remove_index :members, :criminal_role
    execute "ALTER TABLE members DROP CONSTRAINT IF EXISTS members_criminal_role_check"
    remove_column :members, :criminal_role
  end
end
