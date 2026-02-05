# === CONFIG ===
REGIDOR_ROLE = "Regidor"
ALCALDE_ROLE = "Alcalde"

ROLE_A = "Jefe"
ROLE_B = "Colaborador"

# 1) Detectar columna de fecha en hits
hit_date_col =
  (Hit.column_names & %w[date hit_date published_at event_date captured_at created_at]).first || "created_at"

puts "Usando columna de fecha para hits: #{hit_date_col}"

# 2) Base scope: regidores involucrados=false
regidores = Member.joins(:role)
  .where(roles: { name: REGIDOR_ROLE })
  .where(involved: false)

created = 0
checked = 0

regidores.find_each(batch_size: 500) do |reg|
  checked += 1

  # 3) Fecha del primer hit (many-to-many)
  first_hit_date = Hit.joins("JOIN hits_members hm ON hm.hit_id = hits.id")
    .where("hm.member_id = ?", reg.id)
    .order("hits.#{hit_date_col} ASC")
    .limit(1)
    .pluck("hits.#{hit_date_col}")
    .first

  next unless first_hit_date
  hit_date = first_hit_date.to_date

  # 4) Buscar alcalde (misma organización, involved=true, periodo contiene hit_date)
  alcalde = Member.joins(:role)
    .where(organization_id: reg.organization_id)
    .where(roles: { name: ALCALDE_ROLE })
    .where(involved: true)
    .where("members.start_date IS NOT NULL")
    .where("members.start_date <= ?", hit_date)
    .where("members.end_date IS NULL OR members.end_date >= ?", hit_date)
    .order("members.start_date DESC, members.id DESC") # si hay varios, el más reciente
    .first

  next unless alcalde

  # 5) Evitar duplicados (en cualquier dirección)
  exists = MemberRelationship.where(
    "(member_a_id = ? AND member_b_id = ? AND role_a = ? AND role_b = ?) OR (member_a_id = ? AND member_b_id = ? AND role_a = ? AND role_b = ?)",
    alcalde.id, reg.id, ROLE_A, ROLE_B,
    reg.id, alcalde.id, ROLE_A, ROLE_B
  ).exists?

  next if exists

  MemberRelationship.create!(
    member_a_id: alcalde.id,
    member_b_id: reg.id,
    role_a: ROLE_A,
    role_b: ROLE_B,
    role_a_gender: ROLE_A,   # si luego quieres género real, lo ajustamos
    role_b_gender: ROLE_B
  )

  created += 1
end

puts "Regidores revisados: #{checked}"
puts "Relaciones creadas: #{created}"