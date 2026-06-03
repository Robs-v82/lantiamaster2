namespace :sepomex do
  desc "Populate county aliases from SEPOMEX catalog"
  task populate_aliases: :environment do
    require 'rexml/document'
    require 'set'

    sepomex_file = '/Users/robertovalladares/Downloads/CPdescarga.xml'

    unless File.exist?(sepomex_file)
      puts "❌ Error: SEPOMEX file not found at #{sepomex_file}"
      return
    end

    puts "📂 Parsing SEPOMEX XML file (this may take a minute)..."
    start_time = Time.now

    # Parse XML and extract unique (c_estado, c_mnpio) -> d_ciudad pairs
    aliases_map = {}
    processed_rows = 0
    skipped_rows = 0

    begin
      File.open(sepomex_file, 'r', encoding: 'UTF-8') do |file|
        # Read and parse XML
        doc = REXML::Document.new(file)

        # Find all table elements
        REXML::XPath.each(doc, '//table') do |table|
          c_estado = table.elements['c_estado']&.text.to_s.strip
          c_mnpio = table.elements['c_mnpio']&.text.to_s.strip
          d_ciudad = table.elements['d_ciudad']&.text.to_s.strip
          d_mnpio = table.elements['D_mnpio']&.text.to_s.strip

          processed_rows += 1

          # Skip if key fields are missing
          if c_estado.blank? || c_mnpio.blank? || d_ciudad.blank?
            skipped_rows += 1
            next
          end

          # Skip if d_ciudad equals D_mnpio (not a meaningful alias)
          if d_ciudad.downcase == d_mnpio.to_s.downcase
            skipped_rows += 1
            next
          end

          # Create composite key
          key = "#{c_estado}|#{c_mnpio}"

          # Store only the first unique city name for this municipality
          unless aliases_map.key?(key)
            aliases_map[key] = {
              c_estado: c_estado,
              c_mnpio: c_mnpio,
              d_ciudad: d_ciudad,
              d_mnpio: d_mnpio
            }
          end

          # Progress indicator
          puts "\r⏳ Processed: #{processed_rows} rows | Aliases found: #{aliases_map.size}" if processed_rows % 5000 == 0
        end
      end
    rescue => e
      puts "❌ Error parsing XML: #{e.message}"
      return
    end

    parsing_time = Time.now - start_time
    puts "\n✓ Parsed #{processed_rows} rows in #{parsing_time.round(1)}s"
    puts "  Found #{aliases_map.size} unique municipality aliases"
    puts "  Skipped #{skipped_rows} rows (missing data or duplicate names)\n"

    # Populate counties with aliases
    puts "🔗 Building County lookup index (this is fast)..."
    start_index = Time.now

    # Pre-load all counties with state codes into memory for O(1) lookup
    county_lookup = {}
    County.joins(:state).pluck(:code, 'states.code', :id).each do |(county_code, state_code, county_id)|
      key = "#{state_code}|#{county_code}"
      county_lookup[key] = county_id
    end
    puts "  ✓ Indexed #{county_lookup.size} counties in #{(Time.now - start_index).round(1)}s"

    # Also pre-load all existing aliases to avoid duplicates
    existing_aliases = Set.new
    CountyAlias.pluck(:county_id, :alias_name).each do |(county_id, alias_name)|
      existing_aliases.add("#{county_id}|#{alias_name}")
    end
    puts "  ✓ Found #{existing_aliases.size} existing aliases"

    puts "\n🔗 Linking aliases to County records..."
    created_count = 0
    not_found_count = 0
    skipped_existing = 0

    aliases_map.each_with_index do |(key, data), index|
      state_code = data[:c_estado]
      mun_code = data[:c_mnpio]
      alias_name = data[:d_ciudad]

      # Lookup county ID using pre-built index
      lookup_key = "#{state_code}|#{mun_code}"
      county_id = county_lookup[lookup_key]

      unless county_id
        not_found_count += 1
        next
      end

      # Check if alias already exists
      alias_key = "#{county_id}|#{alias_name}"
      if existing_aliases.include?(alias_key)
        skipped_existing += 1
        next
      end

      # Create alias
      alias_record = CountyAlias.new(
        county_id: county_id,
        alias_name: alias_name,
        alias_type: 'common_name'
      )

      if alias_record.save
        created_count += 1
      else
        puts "  ⚠️  Failed to save alias for county #{county_id}: #{alias_record.errors.full_messages.join(', ')}"
      end

      # Progress indicator
      if (index + 1) % 5000 == 0
        puts "\r⏳ Processing: #{index + 1}/#{aliases_map.size}"
      end
    end

    puts "\n" + "="*80
    puts "✅ SEPOMEX ALIAS POPULATION COMPLETE"
    puts "="*80
    puts "  Created new aliases:    #{created_count}"
    puts "  Skipped (already exist): #{skipped_existing}"
    puts "  Not found in DB:        #{not_found_count}"
    puts "  Total processed:        #{aliases_map.size}"
    puts "="*80
  end
end
