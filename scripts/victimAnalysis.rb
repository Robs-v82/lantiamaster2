# script/victimAnalysis.rb

require "csv"

# Catálogo para type_of_place de Killings
TYPE_OF_PLACE_CATALOG = [
  {
    string: "Vía pública",
    typeArr: [
      "Vía pública (calle, avenida, banqueta, carretera)",
      "Transporte privado (automóvil, motocicleta, bicileta)",
      "Transporte oficial (patrulla, automóvil de alguna dependencia pública, ambulancia institución pública)",
      "Transporte de carga"
    ]
  },
  {
    string: "Inmueble habitacional",
    typeArr: [
      "Inmueble habitacional propiedad del ejecutado (dentro o fuera)",
      "Inmueble habitacional privado"
    ]
  },
  {
    string: "Comercio",
    typeArr: [
      "Local comercial (taller, tiendita, farmacia, tortillería)",
      "Inmueble comercial (centro comercial, gasolinera, hotel, bar)",
      "Inmueble privado (oficina, manufactura, fábrica, edificio, finca, iglesia)"
    ]
  },
  {
    string: "Transporte de pasajeros",
    typeArr: [
      "Transporte público colectivo (autobús, metro, tren)",
      "Transporte público privado (taxi, UBER, mototaxi)"
    ]
  },
  {
    string: "Otro tipo/No especificado",
    typeArr: [
      "Espacio público abierto (parque, panteón, plaza pública, terminales)",
      "Espacio público cerrado (museo, oficinas o instituciones gubernamentales, escuelas)",
      "Predios o parajes (lotes baldíos, obra negra, campos abiertos)",
      "Centro de readaptación social",
      "Institución, centro o clínica de salud",
      "Centro de rehabilitación de adicciones AA",
      "No especificado",
      nil
    ]
  }
].freeze

def classify_type_of_place(original)
  entry = TYPE_OF_PLACE_CATALOG.find { |e| e[:typeArr].include?(original) }
  entry ? entry[:string] : "Otro tipo/No especificado"
end

# Catálogo para Victim.legacy_role_officer
VICTIM_ROLE_CATALOG = [
  {
    name: "Militar",
    categories: [
      "Militar SEDENA",
      "Militar SEMAR"
    ]
  },
  {
    name: "PF/GN",
    categories: [
      "Policía Federal",
      "Alto Mando Policía Federal",
      "Guardia Nacional"
    ]
  },
  {
    name: "Policía Estatal",
    categories: [
      "Policía Estatal (caminos)",
      "Policía Estatal (investigación)",
      "Policía Estatal (procesal)",
      "Policía Estatal (reacción)",
      "Policía Estatal (auxiliar)",
      "Policía Estatal (custodio penitenciario)",
      "Policía Estatal (bancaria)",
      "Policía Estatal (no especificado)",
      "Alto Mando Policía Estatal"
    ]
  },
  {
    name: "Policía Municipal",
    categories: [
      "Policía Municipal (preventivo)",
      "Policía Municipal (tránsito o vial)",
      "Policía Municipal (comunitario)",
      "Policía Municipal (no especificado)",
      "Alto Mando Policía Municipal"
    ]
  },
  {
    name: "Policía Ministerial",
    categories: [
      "Policía Ministerial, Fiscalías, Procuradurías, Judicial",
      "Alto Mando Policía Ministerial, Fiscalías, Procuradurías"
    ]
  },
  {
    name: "Policía no identificado",
    categories: [
      "Policía No Especificado u otro",
      "Alto Mando Policía No Especificado",
      "Otro cuerpo policial local (autodefensas)",
      "Otro cuerpo policial local (fuerza rural)",
      "Otro cuerpo policial local (fuerza civil)",
      "Otro cuerpo policial local (fuerza ciudadana)",
      "Alto Mando Otro Cuerpo Policial Local"
    ]
  },
  {
    name: "Civil deliberadamente ejecutado",
    categories: [
      "Civil deliberadamente ejecutado",
      "Civil deliberadamente ejecutdo",
      "Civil aparentemente involucrado con el crimen organizado"
    ]
  },
  {
    name: "Civil accidentalmente ejecutado",
    categories: [
      "Civil accidentalmente ejecutado"
    ]
  },
  {
    name: "Otro/No especificado",
    categories: [
      nil,
      "Civil no especificado",
      "Funcionario Público",
      "Interno penitenciario",
      "Seguridad Privada",
      "No especificado",
      "José Alejandro"
    ]
  }
].freeze

def classify_legacy_role(role)
  entry = VICTIM_ROLE_CATALOG.find { |e| e[:categories].include?(role) }
  entry ? entry[:name] : "Otro/No especificado"
end

# Headers para Killings
killings_headers = [
  "id",
  "date",
  "county_code",
  "county_name",
  "number_of_victims",
  "number_of_offenders",
  "shooting",
  "shooting_between_criminals_and_authorities",
  "type_of_place"
]

# Headers para Victims
victims_headers = [
  "id",
  "killing_id",
  "gender",
  "age",
  "legacy_role_officer" # reclasificado
]

years = (2018..2024).map(&:to_s)

# Frecuencias de type_of_place por año
killings_frequencies = Hash.new { |h, year| h[year] = Hash.new(0) }

# Frecuencias de tipo de víctima (legacy_role_officer reclasificado) por año
victims_frequencies = Hash.new { |h, year| h[year] = Hash.new(0) }

Year.where(name: years).find_each do |year|
  # ---- Killings CSV por año ----
  killings_path = File.join(Dir.home, "Desktop", "killingsOutput#{year.name}.csv")

  CSV.open(killings_path, "w", write_headers: true, headers: killings_headers) do |csv|
    year.killings.includes(event: { town: :county }, victims: []).find_each do |killing|
      event  = killing.event
      town   = event&.town
      county = town&.county

      type_cat = classify_type_of_place(killing.type_of_place)

      csv << [
        killing.id,
        event&.event_date&.to_date,
        county&.full_code,
        county&.name,
        killing.victims.count,
        killing.aggresor_count,
        !!killing.any_shooting,
        !!killing.shooting_between_criminals_and_authorities,
        type_cat
      ]

      killings_frequencies[year.name][type_cat] += 1
    end
  end

  # ---- Victims CSV por año ----
  victims_path = File.join(Dir.home, "Desktop", "victimsOutput#{year.name}.csv")

  CSV.open(victims_path, "w", write_headers: true, headers: victims_headers) do |csv|
    year.victims.includes(:killing).find_each do |victim|
      role_group = classify_legacy_role(victim.legacy_role_officer)

      csv << [
        victim.id,
        victim.killing_id,
        victim.gender,
        victim.age,
        role_group
      ]

      victims_frequencies[year.name][role_group] += 1
    end
  end
end

# ---- Tabla de frecuencias: Killings por type_of_place ----
puts "Frecuencias de type_of_place por año:"
puts "-------------------------------------"

killings_frequencies.keys.sort.each do |year_name|
  puts "\nAño #{year_name}:"
  killings_frequencies[year_name].sort_by { |type, count| -count }.each do |type, count|
    puts "  #{type}: #{count}"
  end
end

# ---- Tabla de frecuencias: Víctimas por tipo (legacy_role_officer reclasificado) ----
puts "\nFrecuencias de tipo de víctima (legacy_role_officer reclasificado) por año:"
puts "----------------------------------------------------------------------------"

victims_frequencies.keys.sort.each do |year_name|
  puts "\nAño #{year_name}:"
  victims_frequencies[year_name].sort_by { |type, count| -count }.each do |type, count|
    puts "  #{type}: #{count}"
  end
end




