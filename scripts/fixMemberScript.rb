# fixMemberScript.rb
# Lista members que quedarían clasificados como "Autoridad expuesta" (según tu lógica)
# y que NO tengan ninguna relación en MemberRelationship.
# (Opcional pero alineado a tu Members Search): también exige que tengan al menos un hit.

def clasificar_rol_local(member)
  role_name = member.role&.name.to_s.strip
  involved  = member.involved

  miembros = [
    "Operador", "Jefe regional u operador", "Extorsionador-narcomenudista", "Jefe de sicarios", "Sicario",
    "Jefe de plaza", "Jefe de célula", "Extorsionador", "Secuestrador", "Traficante o distribuidor",
    "Narcomenudista", "Jefe operativo", "Jefe regional", "Sin definir"
  ]

  licitos = ["Abogado", "Músico", "Manager", "Servicios lícitos", "Periodista", "Dirigente sindical", "Artista"]

  autoridades = ["Autoridad cooptada", "Autoridad expuesta", "Gobernador", "Alcalde", "Regidor", "Delegado estatal",
                 "Coordinador estatal", "Secretario de Seguridad", "Policía", "Militar"]

  return "Líder" if role_name == "Líder"
  return "Socio" if role_name == "Socio"
  return "Familiar/allegado" if role_name == "Familiar"
  return "Autoridad cooptada" if role_name == "Autoridad vinculada"
  return "Autoridad expuesta" if role_name == "Autoridad expuesta"

  if autoridades.include?(role_name)
    return involved ? "Autoridad vinculada" : "Autoridad expuesta"
  end

  return "Servicios lícitos" if licitos.include?(role_name)
  return "Miembro" if miembros.include?(role_name)

  "Sin clasificar"
end

# --- Config / tablas ---
join_table = Hit.reflect_on_association(:members).join_table # e.g. "hits_members"

autoridades_roles = ["Autoridad cooptada", "Autoridad expuesta", "Gobernador", "Alcalde", "Regidor", "Delegado estatal",
                     "Coordinador estatal", "Secretario de Seguridad", "Policía", "Militar"]

# Prefiltro SQL (para no recorrer toda la tabla):
# - Debe tener rol en el set de autoridades o ser "Autoridad expuesta"
# - Debe tener al menos un hit (EXISTS en la join table)
# - No debe tener ninguna relación (EXISTS en member_relationships)
r = Role.find_by(:name=>"Regidor")

candidates = Member
  .joins(:role)
  .where(roles: { name: autoridades_roles })
  .where(:role=>r)
  .where("EXISTS (SELECT 1 FROM #{join_table} hm WHERE hm.member_id = members.id)")
  .where("NOT EXISTS (SELECT 1 FROM member_relationships mr WHERE mr.member_a_id = members.id OR mr.member_b_id = members.id)")
  .includes(:role)
  .distinct

puts "\n=== Autoridad expuesta SIN relaciones (con al menos un hit) ===\n\n"

count = 0
candidates.find_each(batch_size: 1000) do |m|
  next unless clasificar_rol_local(m) == "Autoridad expuesta"

  full_name = [m.firstname, m.lastname1, m.lastname2].map { |x| x.to_s.strip }.reject(&:empty?).join(" ")
  puts "----------------------------------------" if count > 0
  puts "#{full_name} - #{m.id}"
  count += 1
end

puts "\n\nTotal: #{count}\n"
