class CreateVictims < ActiveRecord::Migration[6.0]
  def change
    create_table :victims do |t|
      t.string :firstname
      t.string :lastname1
      t.string :lastname2
      t.string :alias
      t.integer :gender
      t.integer :age
      t.integer :age_in_months
      t.boolean :innocent_bystander
      t.boolean :reported_cartel_member
      t.boolean :agressor
      t.boolean :acuchillado
      t.boolean :a_golpes
      t.boolean :asfixiado
      t.boolean :baleado
      t.boolean :con_tiro_de_gracia
      t.boolean :calcinado
      t.boolean :cinta_adhesiva_en_la_cabeza
      t.boolean :colgado
      t.boolean :con_dedos_en_la_boca
      t.boolean :con_la_lengua_cortada
      t.boolean :con_mensaje_escrito
      t.boolean :con_mensaje_escrito_en_el_cuerpo
      t.boolean :con_senales_de_tortura
      t.boolean :crucificado
      t.boolean :decapitado_cabeza_sin_cuerpo
      t.boolean :decapitado_cuerpo_sin_cabeza
      t.boolean :degollado
      t.boolean :descalzo
      t.boolean :descuartizado
      t.boolean :desnudo
      t.boolean :disuelto_en_acido
      t.boolean :embolsado
      t.boolean :encobijado
      t.boolean :enlonado
      t.boolean :enterrado
      t.boolean :esposado
      t.boolean :extraccion_del_globo_ocular
      t.boolean :hincado
      t.boolean :manos_atadas_al_frente
      t.boolean :manos_atadas_atras
      t.boolean :mutilacion
      t.boolean :mutilacion_de_genitales
      t.boolean :mutilacion_de_otra_parte
      t.boolean :piedra_u_objeto_pesado
      t.boolean :pies_atados
      t.boolean :semidesnudo
      t.boolean :semienterrado
      t.string :otra_forma
      t.references :role, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :killing, null: false, foreign_key: true

      t.timestamps
    end
  end
end
