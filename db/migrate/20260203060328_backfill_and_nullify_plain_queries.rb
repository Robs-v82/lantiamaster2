class BackfillAndNullifyPlainQueries < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!  # para ir por batches sin locks largos

  class LegacyQuery < ApplicationRecord
    self.table_name = "queries"
    self.ignored_columns = [] # IMPORTANT: leer columnas en claro aunque el modelo real las ignore

    require "lockbox"
    require "blind_index"

    has_encrypted :firstname, :lastname1, :lastname2, :query_label, :outcome

    blind_index :query_label do |value|
      I18n.transliterate(value.to_s.strip.downcase).gsub(/\s+/, " ")
    end
  end

  def up
    LegacyQuery.reset_column_information

    LegacyQuery.in_batches(of: 500) do |batch|
      batch.each do |q|
        # 1) Construir label desde claro (si hace falta)
        label =
          q.query_label.presence ||
          [q.firstname, q.lastname1, q.lastname2].compact.join(" ").strip

        # 2) Escribir a cifrado (solo si hay datos)
        touched = false

        if label.present?
          q.query_label = label
          touched = true
        end

        if q.firstname.present?
          q.firstname = q.firstname
          touched = true
        end

        if q.lastname1.present?
          q.lastname1 = q.lastname1
          touched = true
        end

        if q.lastname2.present?
          q.lastname2 = q.lastname2
          touched = true
        end

        if q.outcome.present?
          q.outcome = q.outcome
          touched = true
        end

        next unless touched

        # Guarda ciphertext + blind index sin validaciones
        q.save!(validate: false)

        # 3) Nullify columnas en claro
        q.update_columns(
          firstname: nil,
          lastname1: nil,
          lastname2: nil,
          query_label: nil,
          outcome: nil
        )
      end
    end
  end

  def down
    # No reversible (no podemos reconstruir el claro sin llaves y decisión explícita)
  end
end
