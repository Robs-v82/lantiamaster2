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
    puts "🔗 Linking aliases to County records..."
    created_count = 0
    updated_count = 0
    not_found_count = 0
    skipped_existing = 0

    aliases_map.each_with_index do |(key, data), index|
      # Find County by state code and municipality code
      # Note: County.code is the 3-digit municipality code
      state_code = data[:c_estado]
      mun_code = data[:c_mnpio]
      state = State.where("code = ? OR LPAD(code::text, 2, '0') = ?", state_code, state_code).first

      unless state
        not_found_count += 1
        next
      end

      county = state.counties.where(code: mun_code).first
      unless county
        not_found_count += 1
        next
      end

      # Create or skip CountyAlias
      alias_record = county.county_aliases.find_by(alias_name: data[:d_ciudad])
      if alias_record
        skipped_existing += 1
      else
        alias_record = county.county_aliases.build(
          alias_name: data[:d_ciudad],
          alias_type: 'common_name'
        )

        if alias_record.save
          created_count += 1
        else
          puts "  ⚠️  Failed to save alias for #{county.name}: #{alias_record.errors.full_messages.join(', ')}"
        end
      end

      # Progress indicator
      if (index + 1) % 2000 == 0
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
