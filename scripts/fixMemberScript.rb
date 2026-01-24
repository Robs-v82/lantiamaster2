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

candidate_ids = candidates.pluck(:id)
candidate_id_set = candidate_ids.to_h { |id| [id, true] }

hits = Hit
  .joins(:members)
  .where(members: { id: candidate_ids })
  .includes(:members, town: { county: :state })
  .distinct
  .order(date: :desc, id: :desc)

feminine_role_map = {
  "Padre" => "Madre", "Hijo" => "Hija", "Abuelo" => "Abuela", "Nieto" => "Nieta",
  "Tio" => "Tia", "Sobrino" => "Sobrina", "Padrino" => "Madrina", "Ahijado" => "Ahijada",
  "Abogado" => "Abogada", "Defendido" => "Defendida", "Jefe" => "Jefa", "Colaborador" => "Colaboradora",
  "Hermano" => "Hermana", "Compañero" => "Compañera", "Amigo" => "Amiga", "Primo" => "Prima",
  "Conyuge" => "Conyuge", "Pareja" => "Pareja", "Esposo" => "Esposa", "Socio" => "Socia",
  "Allegado" => "Allegada", "Compadre" => "Comadre", "Cuñado" => "Cuñada", "Suegro" => "Suegra",
  "Yerno" => "Nuera"
}

create_link = lambda do |member_a, member_b, role_a|
  return if member_a.blank? || member_b.blank?
  return if member_a.id == member_b.id

  role_a = role_a.to_s.strip
  role_b = (role_a == "Colaborador" ? "Jefe" : role_a) # aquí lo dejamos fijo para tu caso

  role_a_gender = member_a.gender == "FEMENINO" ? (feminine_role_map[role_a] || role_a) : role_a
  role_b_gender = member_b.gender == "FEMENINO" ? (feminine_role_map[role_b] || role_b) : role_b

  existe = MemberRelationship.exists?(member_a_id: member_a.id, member_b_id: member_b.id, role_a: role_a, role_b: role_b) ||
           MemberRelationship.exists?(member_a_id: member_b.id, member_b_id: member_a.id, role_a: role_b, role_b: role_a)

  unless existe
    MemberRelationship.create!(
      member_a: member_a,
      member_b: member_b,
      role_a: role_a,
      role_b: role_b,
      role_a_gender: role_a_gender,
      role_b_gender: role_b_gender
    )
  end
end


hits.each do |hit|
  miembros = hit.members.select { |m| candidate_id_set[m.id] }
  next if miembros.empty?

  lugar = [
    hit.town&.name.to_s.strip.presence,
    hit.town&.county&.name.to_s.strip.presence,
    hit.town&.county&.state&.shortname.to_s.strip.presence
  ].compact.join(", ")

  fecha = hit.date ? hit.date.strftime("%d/%m/%Y") : ""

  # --- INSERTAR AQUÍ (dentro de hits.each), antes de imprimir el encabezado ---

  hit_date = hit.date
  county = hit.town&.county

  mayor_name = nil

  if county && hit_date
    gov_org_prefix = "Gobierno Municipal de #{county.name}".to_s.strip

    gov_org = county.organizations
      .where("name ILIKE ?", "#{gov_org_prefix}%")
      .order(:id)
      .first

    mayor = nil

    if gov_org
      mayor = gov_org.members
        .joins(:role)
        .where(roles: { name: "Alcalde" })
        .where(involved: true)
        .where("start_date IS NULL OR start_date <= ?", hit_date)
        .where("end_date IS NULL OR end_date >= ?", hit_date)
        .order(:id)
        .first

      if mayor
        mayor_name = [mayor.firstname, mayor.lastname1, mayor.lastname2].map { |x| x.to_s.strip }.reject(&:blank?).join(" ")
      end
    end
  end

  mayor_line = mayor_name.present? ? "Alcalde involved: Sí - #{mayor_name}" : "Alcalde involved: No"

  puts "#{lugar} - #{fecha}".strip
  puts mayor_line
  puts ""

  miembros.sort_by { |m| [m.lastname1.to_s, m.lastname2.to_s, m.firstname.to_s, m.id] }.each do |m|
    full_name = [m.firstname, m.lastname1, m.lastname2].map { |x| x.to_s.strip }.reject(&:blank?).join(" ")
    puts "#{full_name} - #{m.id}"
  end

  # --- INSERTAR AQUÍ: crear relaciones Regidor -> Alcalde (solo si hay alcalde involved) ---

  if mayor.present?
    ActiveRecord::Base.transaction do
      miembros.each do |reg|
        next if reg.id == mayor.id
        create_link.call(reg, mayor, "Colaborador")
      end
    end
  end

  puts ""
  puts "------------------------------------------------------------"
  puts ""
end
