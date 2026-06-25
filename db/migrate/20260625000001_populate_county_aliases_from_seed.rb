class PopulateCountyAliasesFromSeed < ActiveRecord::Migration[6.0]
  def up
    require 'csv'

    csv_path = Rails.root.join('scripts', 'county_aliases_seed.csv')

    unless File.exist?(csv_path)
      puts "⚠️  CSV file not found at #{csv_path}"
      return
    end

    puts "📖 Loading county aliases from #{csv_path}"
    puts ""

    loaded = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      alias_name = row['alias']&.strip
      municipality_name = row['municipality']&.strip
      state_name = row['state']&.strip

      # Skip empty rows
      next if alias_name.blank? || municipality_name.blank? || state_name.blank?

      # Find state
      state = State.find_by("LOWER(name) = ?", state_name.downcase)
      unless state
        errors << "Estado no encontrado: '#{state_name}'"
        next
      end

      # Find county within the state
      county = state.counties.find_by("LOWER(name) = ?", municipality_name.downcase)
      unless county
        errors << "Municipio no encontrado en #{state_name}: '#{municipality_name}'"
        next
      end

      # Check if alias already exists
      existing = CountyAlias.find_by(county_id: county.id, alias_name: alias_name)
      if existing
        puts "⏭️  Alias ya existe: '#{alias_name}' → #{county.name}"
        next
      end

      # Create the alias
      begin
        CountyAlias.create!(
          county_id: county.id,
          alias_name: alias_name,
          alias_type: 'common_name'
        )
        puts "✓ Creado: '#{alias_name}' → #{county.name} (#{state.name})"
        loaded += 1
      rescue => e
        errors << "Error al crear alias '#{alias_name}' para #{county.name}: #{e.message}"
      end
    end

    puts ""
    puts "=" * 70
    puts "📊 RESUMEN:"
    puts "  ✓ Aliases cargados: #{loaded}"
    puts "  ⚠️  Errores/Advertencias: #{errors.count}"
    if errors.any?
      puts ""
      puts "ERRORES:"
      errors.each { |e| puts "  - #{e}" }
    end
    puts "=" * 70
  end

  def down
    # Remove all aliases created by this migration
    # We can identify them as those with alias_type = 'common_name' and created after this migration
    # For safety, we'll just delete all and let the user handle rollback manually
    puts "⚠️  Rolling back would delete all county aliases. Please handle manually."
  end
end
