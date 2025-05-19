require 'csv'
require 'securerandom'

def alcaldes_prioritarios_con_hits
  alcalde_role_id = Role.find_by(name: 'Alcalde')&.id
  return puts "⚠️ Rol 'Alcalde' no encontrado" unless alcalde_role_id

  start_date = Quarter.where(name: "2020_Q1").last.first_day
  user_id = User.where(mail: "roberto@lantiaintelligence.com").last&.id
  not_found = []
  results = []

  municipios = {
    "Guerrero" => ["San Miguel Totolapan", "Pilcaya", "Ajuchitlán del Progreso", "Arcelia", "Coyuca de Catalán",
                   "Cutzamala de Pinzón", "Pungarabato", "Cocula", "Zirándaro", "Tlapehuala"],
    "Michoacán" => ["Aguililla", "Buenavista", "Tepalcatepec", "Coalcomán de Vázquez Pallares", "Chinicuila",
                    "La Huacana", "Tumbiscatío", "Arteaga", "Múgica"],
    "México" => ["Tlatlaya", "Luvianos"],
    "Sinaloa" => ["Badiraguato", "Choix", "Sinaloa"],
    "Jalisco" => ["Teuchitlán", "Tala"],
    "Morelos" => ["Miacatlán", "Puente de Ixtla", "Amacuzac", "Mazatepec"],
    "Tamaulipas" => ["Mier", "Miguel Alemán", "Camargo", "Gustavo Díaz Ordaz", "Valle Hermoso", "San Fernando"]
  }

  municipios.each do |estado, nombres_municipios|
    state = State.find_by(name: estado)
    next unless state

    nombres_municipios.each do |nombre_municipio|
      county = County.where(state_id: state.id).find_by(name: nombre_municipio)
      if county.nil?
        not_found << "#{estado} - #{nombre_municipio}"
        next
      end

      county_organizations = county.organizations
      alcaldes = Member.where(role_id: alcalde_role_id)
                       .joins(:organization)
                       .where(organizations: { id: county_organizations.pluck(:id) })
                       .where("end_date >= ?", start_date)

      alcaldes.each do |alcalde|
        next unless alcalde.start_date && alcalde.end_date

        quarters = Quarter.where("first_day >= ? AND first_day <= ?", alcalde.start_date, alcalde.end_date)
        q_start = quarters.map(&:first_day).min
        q_end = quarters.map { |q| q.first_day + 3.months - 1.day }.max
        quarter_ids = quarters.pluck(:id)

        # Buscar leads en municipio
        lead_scope = Lead.joins(event: { town: :county })
                         .where(towns: { county_id: county.id })
                         .where(events: { event_date: q_start..q_end })
                         .where.not(events: { organization_id: nil })

        org_with_most_leads = lead_scope.group('events.organization_id')
                                        .order('COUNT(*) DESC')
                                        .limit(1)
                                        .pluck('events.organization_id')
                                        .first

        # Buscar leads en estado si no hay en municipio
        if org_with_most_leads.nil?
          lead_scope_state = Lead.joins(event: { town: { county: :state } })
                                 .where(states: { id: state.id })
                                 .where(events: { event_date: q_start..q_end })
                                 .where.not(events: { organization_id: nil })

          org_with_most_leads = lead_scope_state.group('events.organization_id')
                                                .order('COUNT(*) DESC')
                                                .limit(1)
                                                .pluck('events.organization_id')
                                                .first
        end

        org_name = Organization.find_by(id: org_with_most_leads)&.name

        # 🧩 Asignar criminal_link_id
        alcalde.update(criminal_link_id: org_with_most_leads)

        # 🧩 Crear Hit (si no hay otro Member con mismo nombre que ya tenga Hit)
        if user_id
          existing_named_member_with_hit = Member
            .where(firstname: alcalde.firstname, lastname1: alcalde.lastname1, lastname2: alcalde.lastname2)
            .joins(:hits)
            .exists?

          unless existing_named_member_with_hit
            town_code = (county.full_code.to_s + "0000").rjust(9, '0')
            town = Town.find_by(full_code: town_code)

            if town
              legacy_id = "#{Time.now.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(3)}"
              hit = Hit.create!(
                date: alcalde.start_date,
                town_id: town.id,
                user_id: user_id,
                legacy_id: legacy_id
              )
              hit.members << alcalde
            end
          end
        end

        # Agregar al CSV
        results << {
          member_id: alcalde.id,
          firstname: alcalde.firstname,
          lastname1: alcalde.lastname1,
          lastname2: alcalde.lastname2,
          code: county.full_code,
          name: county.name,
          quarter_ids: quarter_ids,
          organization_id: org_with_most_leads,
          organization_name: org_name
        }
      end
    end
  end

  # Generar CSV
  csv_output = CSV.generate(headers: true) do |csv|
    csv << ["member_id", "firstname", "lastname1", "lastname2", "code", "name",
            "quarter_ids", "organization_id", "organization_name"]
    results.each do |row|
      csv << [
        row[:member_id], row[:firstname], row[:lastname1], row[:lastname2],
        row[:code], row[:name], row[:quarter_ids].join(";"),
        row[:organization_id], row[:organization_name]
      ]
    end
  end

  puts "\n🟢 Tabla de alcaldes prioritarios únicos:\n\n"
  puts csv_output

  unless not_found.empty?
    puts "\n🔴 Municipios no encontrados:\n"
    not_found.each { |entry| puts "- #{entry}" }
  end
end

alcaldes_prioritarios_con_hits
Member.where.not(criminal_link_id: nil).where.not(start_date: nil).each{|x| x.update(:media_score=>true)}