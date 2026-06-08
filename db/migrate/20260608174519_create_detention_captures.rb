class CreateDetentionCaptures < ActiveRecord::Migration[6.0]
  def change
    create_table :detention_captures do |t|
      t.string :source_url
      t.date :capture_date
      t.date :incident_date
      t.string :estado
      t.string :municipio
      t.string :full_code
      t.string :capture_hash
      t.string :status, default: 'captured'
      t.text :validation_notes
      t.integer :detenidos
      t.string :organizacion
      t.string :grupo_afiliado
      t.string :nombre
      t.string :apellido_paterno
      t.string :apellido_materno
      t.string :alias
      t.string :genero
      t.integer :edad
      t.string :posicion_liderazgo
      t.string :rol
      t.boolean :sedena, default: false
      t.boolean :semar, default: false
      t.boolean :gn, default: false
      t.boolean :sscp, default: false
      t.boolean :fgr, default: false
      t.boolean :ssp_estatal, default: false
      t.boolean :fge_pgj, default: false
      t.boolean :policia_municipal, default: false
      t.boolean :otro, default: false
      t.datetime :deleted_at
      t.bigint :monthly_export_id

      t.timestamps
    end

    add_index :detention_captures, :capture_hash
    add_index :detention_captures, :status
    add_index :detention_captures, :incident_date
    add_index :detention_captures, :capture_date
    add_index :detention_captures, [:estado, :municipio, :incident_date], name: 'idx_dc_estado_municipio_date'
    add_index :detention_captures, :monthly_export_id
  end
end
