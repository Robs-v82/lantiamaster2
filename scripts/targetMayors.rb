require 'csv'
require 'securerandom'

def target_mayors
  results = []
  alcalde_role_id = Role.find_by(name: 'Alcalde')&.id
  return puts "⚠️ Rol 'Alcalde' no encontrado" unless alcalde_role_id

  Quarter.find_each do |quarter|
    cookie = Cookie.where(category: "irco_counties", quarter_id: quarter.id).last
    next unless cookie && cookie.data.is_a?(Array)

    quarter_start = quarter.first_day
    quarter_end = (quarter_start + 3.months - 1.day)

    cookie.data.each do |record|
      nivel = record["nivel"] || record[:nivel]
      warnings = record["warnings"] || record[:warnings] || []
      name = record["name"] || record[:name] || "SIN NOMBRE"
      code = record["code"] || record[:code]

      next unless nivel == "Crítico" && warnings.include?("Agresiones a autoridades")

      county = County.find_by(full_code: code.to_s.rjust(5, '0'))
      next unless county && county.organizations.any?

      org = county.organizations.first
      alcalde = org.members
                   .where(role_id: alcalde_role_id)
                   .where("start_date <= ? AND end_date >= ?", quarter_start, quarter_start)
                   .first

      next unless alcalde

      leads = county.leads.joins(:event).where(events: { event_date: quarter_start..quarter_end })
      org_with_most_leads = leads.group_by { |lead| lead.event.organization_id }
                                 .max_by { |_, v| v.count }
      lead_org_id = org_with_most_leads&.first
      lead_org_name = Organization.find_by(id: lead_org_id)&.name

      results << {
        quarter_id: quarter.id,
        quarter_name: quarter.name,
        code: code,
        name: name,
        member_id: alcalde.id,
        firstname: alcalde.firstname,
        lastname1: alcalde.lastname1,
        lastname2: alcalde.lastname2,
        organization_id: lead_org_id,
        organization_name: lead_org_name
      }
    end
  end

  # Primer CSV: tabla original
  csv_output_1 = CSV.generate(headers: true) do |csv|
    csv << ["quarter_id", "quarter_name", "code", "name", "member_id",
            "firstname", "lastname1", "lastname2", "organization_id", "organization_name"]
    results.each do |row|
      csv << [row[:quarter_id], row[:quarter_name], row[:code], row[:name],
              row[:member_id], row[:firstname], row[:lastname1], row[:lastname2],
              row[:organization_id], row[:organization_name]]
    end
  end

  puts "\n🟢 Tabla de resultados por trimestre:\n\n"
  puts csv_output_1

  # Segunda tabla: miembros únicos con quarter_ids y organización dominante
  unique_mayors = results.uniq { |r| r[:member_id] }

  csv_output_2 = CSV.generate(headers: true) do |csv|
    csv << ["member_id", "firstname", "lastname1", "lastname2", "code", "name", "quarter_ids", "organization_id", "organization_name"]

    unique_mayors.each do |row|
      member = Member.find_by(id: row[:member_id])
      next unless member && member.start_date && member.end_date

      county = County.find_by(full_code: row[:code].to_s.rjust(5, '0'))
      next unless county

      quarters_in_range = Quarter.where("first_day >= ? AND first_day <= ?", member.start_date, member.end_date)
      quarter_ids = quarters_in_range.pluck(:id)
      quarter_start = quarters_in_range.map(&:first_day).min
      quarter_end = quarters_in_range.map { |q| q.first_day + 3.months - 1.day }.max

      # Buscar leads en el municipio
      lead_scope = Lead.joins(event: { town: :county })
                       .where(towns: { county_id: county.id })
                       .where(events: { event_date: quarter_start..quarter_end })
                       .where.not(events: { organization_id: nil })

      org_with_most_leads = lead_scope.group('events.organization_id')
                                      .order('COUNT(*) DESC')
                                      .limit(1)
                                      .pluck('events.organization_id')
                                      .first

      # Si no hay leads en el municipio, buscar en el estado
      if org_with_most_leads.nil? && county.state
        lead_scope_state = Lead.joins(event: { town: { county: :state } })
                               .where(states: { id: county.state.id })
                               .where(events: { event_date: quarter_start..quarter_end })
                               .where.not(events: { organization_id: nil })

        org_with_most_leads = lead_scope_state.group('events.organization_id')
                                              .order('COUNT(*) DESC')
                                              .limit(1)
                                              .pluck('events.organization_id')
                                              .first
      end

      org_name = Organization.find_by(id: org_with_most_leads)&.name

      # 🧩 Actualizar criminal_link_id
      member.update(criminal_link_id: org_with_most_leads)

      # 🧩 Crear hit
      town_code = (row[:code].to_s + '0000').rjust(9, '0')
      town = Town.find_by(full_code: town_code)
      user_id = User.where(mail: "roberto@lantiaintelligence.com").last&.id

      if town && user_id
        existing_hit = Hit.joins(:members)
                          .where(date: member.start_date, town_id: town.id, user_id: user_id)
                          .where(members: { id: member.id })
                          .first

        unless existing_hit
          legacy_id = "#{Time.now.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(3)}"
          hit = Hit.create!(
            date: member.start_date,
            town_id: town.id,
            user_id: user_id,
            legacy_id: legacy_id
          )
          hit.members << member
        end
      end

      # CSV
      csv << [
        row[:member_id], row[:firstname], row[:lastname1], row[:lastname2],
        row[:code], row[:name], quarter_ids.join(";"),
        org_with_most_leads, org_name
      ]
    end
  end

  puts "\n🟢 Tabla consolidada de miembros únicos:\n\n"
  puts csv_output_2
end

target_mayors
