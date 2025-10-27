# scripts/cleanMembersScripts.rb
# Ejecuta con:
#   rails runner scripts/cleanMembersScripts.rb

require "csv"

CSV_PATH = File.join(Rails.root, "scripts", "Depuración (17102025) - depuración.csv")

# -------- Utilidades puramente Ruby (sin ActiveSupport) --------
def is_blank_value?(v)
  v.nil? || (v.is_a?(String) && v.strip.empty?)
end

def str_or_nil(v)
  return nil if v.nil?
  s = v.to_s.strip
  s.empty? ? nil : s
end

def truthy_flag?(v)
  return false if v.nil?
  s = v.to_s.strip.downcase
  # admite 1, true, sí, si, x
  %w[1 true t yes y si sí x].include?(s)
end

def parse_aliases(raw)
  return [] if is_blank_value?(raw)
  raw.to_s.split(/[;,]/).map { |s| s.strip }.reject(&:empty?).uniq
end
# ---------------------------------------------------------------

unless File.exist?(CSV_PATH)
  puts "[ERROR] No se encontró el CSV en: #{CSV_PATH}"
  exit(1)
end

puts "[INFO] Procesando CSV: #{CSV_PATH}"

rownum  = 0
success = 0
errors  = 0

CSV.foreach(CSV_PATH, headers: true, encoding: "UTF-8") do |row|
  rownum += 1

  member_id       = str_or_nil(row["Member.id"])
  merge_target_id = str_or_nil(row["Fusionar"])
  eliminar_flag   = row["Eliminar"]

  if is_blank_value?(member_id)
    puts "[WARN][fila #{rownum}] Member.id vacío; se omite."
    next
  end

  member = Member.find_by(id: member_id)
  if member.nil?
    puts "[WARN][fila #{rownum}] No existe Member ##{member_id}; se omite."
    next
  end

  # Pre-lee columnas r* y x*
  r_firstname = str_or_nil(row["rMember.firstname"])
  r_lastname1 = str_or_nil(row["rMember.lastname1"])
  r_lastname2 = str_or_nil(row["rMember.lastname2"])
  r_alias_raw = str_or_nil(row["rMember.alias"])

  x_firstname = str_or_nil(row["xMember.firstname"])
  x_lastname1 = str_or_nil(row["xMember.lastname1"])
  x_lastname2 = str_or_nil(row["xMember.lastname2"])

  begin
    ActiveRecord::Base.transaction do
      changed = []

      # 1) Sustituciones r* en el mismo Member
      if r_firstname
        member.firstname = r_firstname
        changed << "firstname"
      end
      if r_lastname1
        member.lastname1 = r_lastname1
        changed << "lastname1"
      end
      if r_lastname2
        member.lastname2 = r_lastname2
        changed << "lastname2"
      end
      if r_alias_raw
        member.alias = parse_aliases(r_alias_raw)
        changed << "alias(#{member.alias.join(', ')})"
      end
      if changed.any?
        member.save!
        puts "[OK][fila #{rownum}] Member ##{member.id} actualizado: #{changed.join(', ')}"
      end

      # 2) Fusionar hits hacia el Member destino (si viene "Fusionar")
      if merge_target_id
        target = Member.find_by(id: merge_target_id)
        raise ActiveRecord::RecordNotFound, "Member destino ##{merge_target_id} no existe" if target.nil?

        source_hits = member.hits.to_a
        if source_hits.any?
          target_hits = target.hits.to_a
          hits_to_add = source_hits.reject { |h| target_hits.include?(h) }
          if hits_to_add.any?
            target.hits << hits_to_add
            target.save!
            puts "[OK][fila #{rownum}] Fusionados #{hits_to_add.size} hit(s) de ##{member.id} → ##{target.id}"
          else
            puts "[INFO][fila #{rownum}] Sin hits nuevos para fusionar (##{member.id} → ##{target.id})"
          end
        else
          puts "[INFO][fila #{rownum}] Member ##{member.id} no tiene hits que fusionar."
        end
      end

      # 3) Crear identidad falsa con x*
      if x_firstname || x_lastname1 || x_lastname2
        # Ajusta el nombre de modelo/campos si tu app usa otros
        fake_identity = member.fake_identities.create!(
          firstname: x_firstname,
          lastname1: x_lastname1,
          lastname2: x_lastname2
        )
        puts "[OK][fila #{rownum}] Identidad falsa creada (##{fake_identity.id}) para Member ##{member.id}"
      end

      # 4) Eliminar Member si corresponde (después de fusionar)
      if truthy_flag?(eliminar_flag)
        id_for_log = member.id
        member.destroy!
        puts "[OK][fila #{rownum}] Member ##{id_for_log} eliminado."
      end
    end

    success += 1
  rescue => e
    errors += 1
    puts "[ERROR][fila #{rownum} | Member ##{member_id}] #{e.class}: #{e.message}"
    # la transacción ya hace rollback al lanzar excepción
  end
end

puts "----"
puts "[RESULTADO] Filas procesadas: #{rownum} | Éxitos: #{success} | Errores: #{errors}"
