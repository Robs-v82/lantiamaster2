class CreateAppointments < ActiveRecord::Migration[6.0]
  def change
    # Requerido para índices/constraints que combinan btree + gist
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :appointments do |t|
      t.references :member,       null: false, foreign_key: true
      t.references :role,         null: false, foreign_key: true
      t.references :organization, null: true,  foreign_key: true
      t.references :county,       null: true,  foreign_key: true

      # Rango de fechas (semiabierto por convención: [start, end))
      t.daterange :period, null: false

      # Precisión de fechas: 0=day, 1=month, 2=year, 3=unknown
      t.integer :start_precision, null: false, default: 0
      t.integer :end_precision,   null: false, default: 0

      t.timestamps
    end

    # Índice GIST para acelerar operaciones con rangos
    add_index :appointments, :period, using: :gist

    # Validaciones a nivel DB para las precisiones
    execute <<~SQL
      ALTER TABLE appointments
      ADD CONSTRAINT appointments_start_precision_chk
      CHECK (start_precision IN (0,1,2,3));

      ALTER TABLE appointments
      ADD CONSTRAINT appointments_end_precision_chk
      CHECK (end_precision IN (0,1,2,3));
    SQL

    # Evitar solapamientos del mismo miembro/rol/organización/county en el tiempo.
    # Permitimos NULL en organization/county usando COALESCE a 0 como centinela.
    execute <<~SQL
      ALTER TABLE appointments
      ADD CONSTRAINT appointments_no_overlap
      EXCLUDE USING gist (
        member_id WITH =,
        role_id WITH =,
        COALESCE(organization_id, 0) WITH =,
        COALESCE(county_id, 0) WITH =,
        period WITH &&
      );
    SQL
  end
end

