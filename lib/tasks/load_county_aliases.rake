namespace :county do
  desc "Load common county aliases (Cancún→Benito Juárez, etc.)"
  task load_aliases: :environment do
    aliases = [
      # Quintana Roo - Benito Juárez (Cancún)
      { county_code: '014', alias: 'Cancún', type: 'common_name', state: 'Quintana Roo' },
      { county_code: '014', alias: 'Cancun', type: 'alternative', state: 'Quintana Roo' },

      # Sinaloa - Ahome (Los Mochis)
      { county_code: '001', alias: 'Los Mochis', type: 'common_name', state: 'Sinaloa' },
      { county_code: '001', alias: 'Los mochis', type: 'alternative', state: 'Sinaloa' },

      # CDMX - Iztapalapa
      { county_code: '007', alias: 'Iztapalapa', type: 'common_name', state: 'Ciudad de México' },

      # Baja California - Tijuana
      { county_code: '004', alias: 'Tijuana', type: 'common_name', state: 'Baja California' },

      # Jalisco - Guadalajara
      { county_code: '039', alias: 'Guadalajara', type: 'common_name', state: 'Jalisco' },

      # Nuevo León - Monterrey
      { county_code: '039', alias: 'Monterrey', type: 'common_name', state: 'Nuevo León' },

      # Veracruz - Xalapa
      { county_code: '103', alias: 'Xalapa', type: 'common_name', state: 'Veracruz' },

      # Querétaro - Santiago de Querétaro
      { county_code: '011', alias: 'Querétaro', type: 'alternative', state: 'Querétaro' },
    ]

    count = 0
    aliases.each do |alias_data|
      # Buscar estado primero
      state = State.where("name LIKE ?", "%#{alias_data[:state]}%").first
      next unless state

      # Buscar county por estado + código
      county = state.counties.find_by(code: alias_data[:county_code])
      next unless county

      alias_record = county.county_aliases.find_or_initialize_by(alias_name: alias_data[:alias])
      if alias_record.new_record?
        alias_record.alias_type = alias_data[:type]
        if alias_record.save
          puts "✓ Agregado: #{alias_data[:alias].ljust(20)} → #{county.name.ljust(30)} (#{alias_data[:type]})"
          count += 1
        else
          puts "✗ Error: #{alias_record.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nTotal de aliases cargados: #{count}"
  end
end
