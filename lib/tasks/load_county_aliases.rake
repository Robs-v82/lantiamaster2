namespace :county do
  desc "Load common county aliases (Cancún→Benito Juárez, etc.)"
  task load_aliases: :environment do
    aliases = [
      # Quintana Roo
      { county_code: '23004', alias: 'Cancún', type: 'common_name' },
      { county_code: '23004', alias: 'Cancun', type: 'alternative' },

      # Sinaloa
      { county_code: '25002', alias: 'Los Mochis', type: 'common_name' },
      { county_code: '25002', alias: 'Los mochis', type: 'alternative' },

      # Coahuila
      { county_code: '05002', alias: 'Saltillo', type: 'common_name' },

      # Jalisco
      { county_code: '14039', alias: 'Guadalajara', type: 'common_name' },

      # Baja California
      { county_code: '02004', alias: 'Tijuana', type: 'common_name' },

      # Estado de México
      { county_code: '15002', alias: 'Ecatepec', type: 'alternative' },

      # Durango
      { county_code: '10010', alias: 'Gómez Palacio', type: 'common_name' },
      { county_code: '10010', alias: 'Gomez Palacio', type: 'alternative' },

      # CDMX
      { county_code: '09009', alias: 'Iztapalapa', type: 'common_name' },

      # Michoacán
      { county_code: '16053', alias: 'Morelia', type: 'common_name' },
    ]

    count = 0
    aliases.each do |alias_data|
      county = County.find_by(code: alias_data[:county_code])
      next unless county

      alias_record = county.county_aliases.find_or_initialize_by(alias_name: alias_data[:alias])
      if alias_record.new_record?
        alias_record.alias_type = alias_data[:type]
        if alias_record.save
          puts "✓ Agregado: #{alias_data[:alias]} → #{county.name} (#{alias_data[:type]})"
          count += 1
        else
          puts "✗ Error: #{alias_record.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nTotal de aliases cargados: #{count}"
  end
end
