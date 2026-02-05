# scripts/fixAppointments.rb

ROLE_NAMES = [
  "Gobernador",
  "Alcalde",
  "Regidor",
  "Delegado estatal",
  "Coordinador estatal",
  "Secretario de Seguridad",
  "Policía",
  "Militar"
].freeze

puts "== fixAppointments =="
puts "Buscando roles: #{ROLE_NAMES.join(', ')}"

roles_by_name = Role.where(name: ROLE_NAMES).pluck(:name, :id).to_h
missing_roles = ROLE_NAMES - roles_by_name.keys
if missing_roles.any?
  puts "WARNING: No se encontraron estos roles en la tabla roles: #{missing_roles.join(', ')}"
end

role_ids = roles_by_name.values
if role_ids.empty?
  puts "No hay roles válidos para procesar. Terminando."
  return
end

scope = Member
  .where(role_id: role_ids)
  .where.not(organization_id: nil)
  .where.not(start_date: nil)
  .where.not(end_date: nil)

members_touched = {}
appointments_created = 0
appointments_skipped_overlap = 0

puts "Members candidatos: #{scope.count}"

scope.find_each(batch_size: 1000) do |m|
  from = m.start_date
  to_exclusive = m.end_date + 1.day

  next if to_exclusive <= from

  base = Appointment.where(
    member_id: m.id,
    role_id: m.role_id,
    organization_id: m.organization_id,
    county_id: nil
  )

  # Si hay cualquier traslape con el rango nuevo, NO crear (evita PG::ExclusionViolation)
  overlaps = base.where(
    "period && daterange(?::date, ?::date, '[)')",
    from,
    to_exclusive
  ).exists?

  if overlaps
    appointments_skipped_overlap += 1
    next
  end

  Appointment.create!(
    member_id: m.id,
    role_id: m.role_id,
    organization_id: m.organization_id,
    county_id: nil,
    period: (from...to_exclusive), # [start, end+1) para término inclusivo
    start_precision: :day,
    end_precision: :day
  )

  appointments_created += 1
  members_touched[m.id] = true
end

puts "== Listo =="
puts "Members a los que se les agregó appointment: #{members_touched.size}"
puts "Appointments generados: #{appointments_created}"
puts "Appointments omitidos por overlap: #{appointments_skipped_overlap}"