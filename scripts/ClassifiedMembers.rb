# script/ClassifiedMembers.rb

# --- Silenciar logs (solo en development) ---
_original_logger = nil
if Rails.env.development?
  _original_logger = ActiveRecord::Base.logger
  ActiveRecord::Base.logger = Logger.new(nil)
  Rails.logger.level = Logger::FATAL if Rails.logger
end

at_exit do
  if Rails.env.development? && _original_logger
    ActiveRecord::Base.logger = _original_logger
  end
end
# --- fin silenciar logs ---

puts "\n=== ClassifiedMembers.rb ==="

target = Member.joins(:hits).distinct
puts "Target members: #{target.count}"

# -----------------------------
# Criterios (tal cual)
# -----------------------------
EXPECTED_TRUE = [
  "Militar", "Coordinador estatal", "Abogado", "Extorsionador", "Manager",
  "Jefe operativo", "Sicario", "Jefe de plaza", "Sin definir", "Regidor",
  "Socio", "Policía", "Operador", "Jefe de célula", "Líder",
  "Traficante o distribuidor", "Delegado estatal", "Artista", "Gobernador",
  "Autoridad cooptada", "Jefe de sicarios", "Dirigente sindical", "Alcalde",
  "Músico", "Narcomenudista", "Secretario de Seguridad", "Jefe regional"
].freeze

MAP_TRUE = {
  "Líder" => ["Líder"],
  "Miembro" => ["Extorsionador", "Jefe operativo", "Sicario", "Jefe de plaza", "Operador",
               "Jefe de célula", "Traficante o distribuidor", "Narcomenudista",
               "Jefe de sicarios", "Jefe regional"],
  "Socio" => ["Abogado", "Manager", "Socio", "Artista", "Dirigente sindical", "Alcalde", "Músico"],
  "Autoridad vinculada" => ["Militar", "Coordinador estatal", "Regidor", "Policía",
                            "Delegado estatal", "Gobernador", "Autoridad cooptada",
                            "Secretario de Seguridad"],
  nil => ["Sin definir"]
}.freeze

EXPECTED_FALSE = [
  "Regidor", "Policía", "Delegado estatal", "Autoridad expuesta", "Artista",
  "Gobernador", "Alcalde", "Secretario de Seguridad", "Coordinador estatal",
  "Servicios lícitos", "Abogado", "Manager", "Dirigente sindical", "Músico",
  "Familiar", "Sin definir"
].freeze

MAP_FALSE = {
  "Autoridad expuesta" => ["Regidor", "Policía", "Delegado estatal", "Autoridad expuesta",
                           "Artista", "Gobernador", "Alcalde", "Secretario de Seguridad", "Coordinador estatal"],
  "Servicios lícitos" => ["Servicios lícitos", "Abogado", "Manager", "Dirigente sindical", "Músico"],
  "Familiar/allegado" => ["Familiar"],
  nil => ["Sin definir"]
}.freeze

# Precalcular lookups role_name -> criminal_role (más rápido)
LOOKUP_TRUE = {}
MAP_TRUE.each { |criminal_role, role_names| role_names.each { |rn| LOOKUP_TRUE[rn] = criminal_role } }

LOOKUP_FALSE = {}
MAP_FALSE.each { |criminal_role, role_names| role_names.each { |rn| LOOKUP_FALSE[rn] = criminal_role } }

def print_freq_table(title, hash)
  rows = hash.sort_by { |k, v| [-v, k.to_s] }
  name_header = "ROL"
  cnt_header  = "COUNT"
  max_name = [name_header.length, rows.map { |r| r[0].to_s.length }.max || 0].max
  max_cnt  = [cnt_header.length, rows.map { |r| r[1].to_s.length }.max || 0].max

  puts "\n=== #{title} ==="
  puts "#{name_header.ljust(max_name)} | #{cnt_header.rjust(max_cnt)}"
  puts "#{"-" * max_name}-+-#{"-" * max_cnt}"
  rows.each { |name, cnt| puts "#{name.to_s.ljust(max_name)} | #{cnt.to_s.rjust(max_cnt)}" }
end

# -----------------------------
# Asignación
# -----------------------------
updated = 0
unchanged = 0
set_nil = 0
skipped_no_role = 0
skipped_unmapped = 0

# Para reporte de out-of-expected
out_true  = Hash.new(0)
out_false = Hash.new(0)

# Solo necesitamos role.name, involved y criminal_role para decidir + update
scope = target.includes(:role).select(:id, :role_id, :involved, :criminal_role)

scope.find_in_batches(batch_size: 1000) do |batch|
  batch.each do |m|
    role_name = m.role&.name
    if role_name.nil?
      skipped_no_role += 1
      next
    end

    if m.involved?
      unless EXPECTED_TRUE.include?(role_name)
        out_true[role_name] += 1
        next
      end
      new_value = LOOKUP_TRUE[role_name]
    else
      unless EXPECTED_FALSE.include?(role_name)
        out_false[role_name] += 1
        next
      end
      new_value = LOOKUP_FALSE[role_name]
    end

    # Si está dentro de expected pero no mapeado (debería no ocurrir)
    if !m.involved? && !LOOKUP_FALSE.key?(role_name) && role_name != "Sin definir"
      skipped_unmapped += 1
      next
    end
    if m.involved? && !LOOKUP_TRUE.key?(role_name) && role_name != "Sin definir"
      skipped_unmapped += 1
      next
    end

    if m.criminal_role == new_value
      unchanged += 1
      next
    end

    # Update directo (sin callbacks/validations)
    m.update_columns(criminal_role: new_value, updated_at: Time.current)
    updated += 1
    set_nil += 1 if new_value.nil?
  end
end

puts "\n--- RESULTADOS ---"
puts "Actualizados: #{updated}"
puts "Sin cambio: #{unchanged}"
puts "Quedaron en nil por regla ('Sin definir'): #{set_nil}"
puts "Skipped (sin role): #{skipped_no_role}"
puts "Skipped (expected pero sin mapeo): #{skipped_unmapped}"

# -----------------------------
# Reporte roles fuera de lo esperado
# -----------------------------
out_total = out_true.values.sum + out_false.values.sum

puts "\n--- ROLES FUERA DE LO ESPERADO (dentro de target) ---"
puts "Total members fuera de lo esperado: #{out_total}"

if out_true.any?
  print_freq_table("Frecuencia por rol (involved=true) fuera de expected", out_true)
else
  puts "\n(involved=true) fuera de expected: 0"
end

if out_false.any?
  print_freq_table("Frecuencia por rol (involved=false) fuera de expected", out_false)
else
  puts "\n(involved=false) fuera de expected: 0"
end

puts "\n=== FIN ClassifiedMembers.rb ===\n"