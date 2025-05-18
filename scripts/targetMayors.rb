require 'csv'

def target_mayors
  results = []
  simultaneous_counties = []

  Quarter.find_each do |quarter|
    cookie = Cookie.where(category: "irco_counties", quarter_id: quarter.id).last
    next unless cookie && cookie.data.is_a?(Array)

    cookie.data.each do |record|
      nivel = record["nivel"] || record[:nivel]
      warnings = record["warnings"] || record[:warnings] || []
      name = record["name"] || record[:name] || "SIN NOMBRE"
      code = record["code"] || record[:code]

      is_critico = (nivel == "Crítico")
      has_agresiones = warnings.include?("Agresiones a autoridades")

      if is_critico || has_agresiones
        results << {
          quarter_id: quarter.id,
          quarter_name: quarter.name,
          code: code,
          name: name,
          crítico: is_critico ? "1" : "0",
          agresiones_autoridades: has_agresiones ? "1" : "0"
        }
      end

      if is_critico && has_agresiones
        simultaneous_counties << [code, name]
      end
    end
  end

  # Generar CSV y luego imprimirlo
  csv_output = CSV.generate(headers: true) do |csv|
    csv << ["quarter_id", "quarter_name", "code", "name", "crítico", "agresiones_autoridades"]
    results.each do |row|
      csv << [row[:quarter_id], row[:quarter_name], row[:code], row[:name], row[:crítico], row[:agresiones_autoridades]]
    end
  end

  puts csv_output

  # Mostrar counties únicos con ambas condiciones
  unique_simultaneous = simultaneous_counties.uniq

  puts "\n📍 Counties únicos que cumplen ambas condiciones (crítico + agresiones a autoridades):"
  unique_simultaneous.each do |code, name|
    puts "- #{code}: #{name}"
  end

  puts "\n✅ Total de counties únicos con ambas condiciones: #{unique_simultaneous.count}"
end

target_mayors
