namespace :sepomex do
  desc "Populate county aliases from SEPOMEX CSV file"
  task populate_aliases_from_csv: :environment do
    require 'csv'

    csv_file = '/Users/robertovalladares/Downloads/municipios_alias_sepomex - municipios_alias_sepomex.csv.csv'

    unless File.exist?(csv_file)
      puts "❌ Error: CSV file not found at #{csv_file}"
      return
    end

    puts "📂 Reading SEPOMEX CSV file..."
    start_time = Time.now

    # Pre-load all counties with state codes into memory for O(1) lookup
    puts "🔗 Building County lookup index..."
    county_lookup = {}
    County.joins(:state).pluck(:code, 'states.code', :id).each do |(county_code, state_code, county_id)|
      key = "#{state_code.to_s.rjust(2, '0')}#{county_code}"
      county_lookup[key] = county_id
    end
    puts "  ✓ Indexed #{county_lookup.size} counties"

    # Pre-load existing aliases
    existing_aliases = Set.new
    CountyAlias.pluck(:county_id, :alias_name).each do |(county_id, alias_name)|
      existing_aliases.add("#{county_id}|#{alias_name}")
    end
    puts "  ✓ Found #{existing_aliases.size} existing aliases\n"

    # Parse CSV and populate aliases
    created_count = 0
    skipped_empty = 0
    not_found_count = 0
    skipped_existing = 0

    CSV.foreach(csv_file, headers: true) do |row|
      clave_inegi = row['clave_inegi'].to_s.strip
      alias_ciudad = row['alias_ciudad'].to_s.strip

      # Skip if alias is empty
      if alias_ciudad.blank?
        skipped_empty += 1
        next
      end

      # Extract state code (first 2 digits) and municipality code (last 3)
      if clave_inegi.match?(/^\d{5}$/)
        state_code = clave_inegi[0..1]
        mun_code = clave_inegi[2..4]
        lookup_key = "#{state_code}#{mun_code}"

        county_id = county_lookup[lookup_key]
        unless county_id
          not_found_count += 1
          next
        end

        # Check if alias already exists
        alias_key = "#{county_id}|#{alias_ciudad}"
        if existing_aliases.include?(alias_key)
          skipped_existing += 1
          next
        end

        # Create alias
        alias_record = CountyAlias.new(
          county_id: county_id,
          alias_name: alias_ciudad,
          alias_type: 'common_name'
        )

        if alias_record.save
          created_count += 1
        else
          puts "  ⚠️  Error: #{alias_record.errors.full_messages.join(', ')}"
        end
      end
    end

    elapsed = Time.now - start_time
    puts "\n" + "="*80
    puts "✅ SEPOMEX CSV ALIAS POPULATION COMPLETE"
    puts "="*80
    puts "  Created new aliases:    #{created_count}"
    puts "  Skipped (already exist): #{skipped_existing}"
    puts "  Skipped (empty alias):   #{skipped_empty}"
    puts "  Not found in DB:        #{not_found_count}"
    puts "  Time elapsed:           #{elapsed.round(2)}s"
    puts "="*80
  end
end
