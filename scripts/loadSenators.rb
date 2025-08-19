# scripts/loadSenators.rb
# Uso: load 'scripts/loadSenators.rb'
require 'csv'
require 'ostruct'

puts "== Carga de Senadores (usa members_similar? de tu app) =="

# ---------- Utilidades ----------
def parse_date(val)
  return nil if val.nil? || val.to_s.strip.empty?
  Date.parse(val.to_s) rescue nil
end

def pick(row, *keys)
  keys.each do |k|
    v = row[k]
    return v if v && !v.to_s.strip.empty?
  end
  nil
end

# Daterange inclusivo [start,end] -> Range Ruby [start, end+1)
def daterange_inclusive(start_d, end_d)
  return nil if start_d.nil? || end_d.nil?
  (start_d...(end_d + 1))
end

def appt_bounds(appt)
  # Lee bounds desde start/end si existen; si no, desde period
  if appt.respond_to?(:start_date) && appt.respond_to?(:end_date) && appt.start_date.present? && appt.end_date.present?
    return [appt.start_date, appt.end_date]
  end
  if appt.respond_to?(:period) && appt.period.present?
    rng = appt.period
    s = rng.begin
    e = rng.end
    e = e - 1 if rng.exclude_end?
    return [s, e]
  end
  [nil, nil]
end

def mergeable_period?(a_start, a_end, b_start, b_end, bridge_days: 30)
  return false if [a_start, a_end, b_start, b_end].any?(&:nil?)
  # Overlap
  return true if (a_start <= b_end) && (b_start <= a_end)
  # Gap (en cualquier sentido)
  if b_start > a_end
    ((b_start - a_end).to_i) <= bridge_days
  elsif a_start > b_end
    ((a_start - b_end).to_i) <= bridge_days
  else
    false
  end
end

def merge_period(a_start, a_end, b_start, b_end)
  [[a_start, b_start].min, [a_end, b_end].max]
end

# ---------- Enlace a tu members_similar? ----------
def call_members_similar(m, candidate_struct)
  # 1) ApplicationController.helpers.members_similar?
  if defined?(ApplicationController) &&
     ApplicationController.respond_to?(:helpers) &&
     ApplicationController.helpers.respond_to?(:members_similar?)
    return ApplicationController.helpers.members_similar?(m, candidate_struct)
  end

  # 2) MembersHelper#members_similar?
  if defined?(MembersHelper) && MembersHelper.instance_methods.map(&:to_sym).include?(:members_similar?)
    @__members_helper__ ||= Object.new.extend(MembersHelper)
    return @__members_helper__.members_similar?(m, candidate_struct)
  end

  # 3) No está disponible: forzar a que lo expongas
  raise "No se encontró `members_similar?`. Expónlo en ApplicationController.helpers o en MembersHelper."
end

def similar_member_for(fn, ln1, ln2)
  # a) intento exacto (case-insensitive simple)
  exact = Member.where("LOWER(firstname)=? AND LOWER(lastname1)=? AND LOWER(lastname2)=?",
                       fn.downcase, ln1.downcase, ln2.downcase).first
  return exact if exact

  cand_struct = OpenStruct.new(firstname: fn, lastname1: ln1, lastname2: ln2)

  # b) candidatos por apellidos (igualdad por LOWER)
  #    Primero ambos apellidos, luego cualquiera de los dos si sigue sin aparecer
  scopes = [
    Member.where("LOWER(lastname1)=? AND LOWER(lastname2)=?", ln1.downcase, ln2.downcase),
    Member.where("LOWER(lastname1)=? OR LOWER(lastname2)=?",  ln1.downcase, ln1.downcase),
    Member.where("LOWER(lastname1)=? OR LOWER(lastname2)=?",  ln2.downcase, ln2.downcase)
  ]

  scopes.each do |scope|
    found = scope.find { |m| call_members_similar(m, cand_struct) }
    return found if found
  end

  nil
end

# ---------- Config ----------
csv_path = Rails.root.join('scripts', 'Senadores - Plataforma.csv')
raise "No se encontró el archivo CSV: #{csv_path}" unless File.exist?(csv_path)

legislador_role = Role.find_or_create_by!(name: 'Legislador')
senado          = Organization.find_or_create_by!(name: 'Senado de la República')

# ---------- Stats ----------
stats = {
  total: 0,
  created_members: 0,
  matched_members: 0,
  new_appointments: 0,
  merged_appointments: 0,
  unchanged_appointments: 0,
  errors: 0
}

# ---------- Proceso principal ----------
CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
  stats[:total] += 1
  begin
    fn  = pick(row, 'member.firstname', 'firstname').to_s.strip
    ln1 = pick(row, 'member.lastname1', 'lastname1').to_s.strip
    ln2 = pick(row, 'member.lastname2', 'lastname2').to_s.strip

    sdate = parse_date(pick(row, 'member.start_date', 'start_date'))
    edate = parse_date(pick(row, 'member.end_date',  'end_date'))

    full_name = [ln1, ln2, fn].reject(&:blank?).join(' ')

    # Buscar coincidencia usando tu lógica
    match = similar_member_for(fn, ln1, ln2)

    new_member = false
    if match.nil?
      match = Member.create!(firstname: fn, lastname1: ln1, lastname2: ln2)
      new_member = true
      stats[:created_members] += 1
    else
      stats[:matched_members] += 1
    end

    # ------- Appointments Legislador @ Senado (period/daterange) -------
    existing_scope = match.appointments.where(role_id: legislador_role.id, organization_id: senado.id)

    existing =
      if Appointment.column_names.include?('period')
        existing_scope.reorder(Arel.sql('lower(period) ASC')).to_a
      elsif Appointment.column_names.include?('start_date')
        existing_scope.order(:start_date).to_a
      else
        existing_scope.to_a
      end

    if existing.empty?
      attrs = { role: legislador_role, organization: senado }
      attrs[:period]     = daterange_inclusive(sdate, edate) if Appointment.column_names.include?('period')
      attrs[:start_date] = sdate if Appointment.column_names.include?('start_date')
      attrs[:end_date]   = edate if Appointment.column_names.include?('end_date')
      match.appointments.create!(attrs)
      stats[:new_appointments] += 1
    else
      new_s, new_e = sdate, edate
      to_merge = []
      existing.each do |ex|
        ex_s, ex_e = appt_bounds(ex)
        if mergeable_period?(ex_s, ex_e, new_s, new_e, bridge_days: 30)
          new_s, new_e = merge_period(ex_s, ex_e, new_s, new_e)
          to_merge << ex
        end
      end

      if to_merge.any?
        keeper = to_merge.shift
        old_s, old_e = appt_bounds(keeper)
        changed = (old_s != new_s || old_e != new_e)

        updates = {}
        updates[:period]     = daterange_inclusive(new_s, new_e) if Appointment.column_names.include?('period')
        updates[:start_date] = new_s if Appointment.column_names.include?('start_date')
        updates[:end_date]   = new_e if Appointment.column_names.include?('end_date')
        keeper.update!(updates)

        to_merge.each { |ex| ex.destroy! }

        if changed
          stats[:merged_appointments] += 1
        else
          stats[:unchanged_appointments] += 1
        end
      else
        attrs = { role: legislador_role, organization: senado }
        attrs[:period]     = daterange_inclusive(new_s, new_e) if Appointment.column_names.include?('period')
        attrs[:start_date] = new_s if Appointment.column_names.include?('start_date')
        attrs[:end_date]   = new_e if Appointment.column_names.include?('end_date')
        match.appointments.create!(attrs)
        stats[:new_appointments] += 1
      end
    end

    puts "#{full_name} — #{new_member ? 'Nuevo Miembro' : 'Miembro repetido'}"
  rescue => e
    stats[:errors] += 1
    warn "ERROR en fila ##{stats[:total]}: #{e.class} - #{e.message}"
  end
end

# ---------- Resumen ----------
puts "\n== Resumen =="
width = 38
fmt = ->(k, v) { printf("%-#{width}s %d\n", k, v) }
fmt.call("Total de filas procesadas:",          stats[:total])
fmt.call("Miembros creados:",                   stats[:created_members])
fmt.call("Miembros repetidos:",                 stats[:matched_members])
fmt.call("Appointments nuevos:",                stats[:new_appointments])
fmt.call("Appointments fusionados/extendidos:", stats[:merged_appointments])
fmt.call("Appointments sin cambio:",            stats[:unchanged_appointments])
fmt.call("Filas con error:",                    stats[:errors])

puts "== Fin =="


