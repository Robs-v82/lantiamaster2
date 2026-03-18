# scripts/allCountiesVictims.rb

require 'csv'

years = (2018..2025).map(&:to_s)
year_map = Year.where(name: years).index_by(&:name)

# Ruta de salida (carpeta Descargas del usuario)
file_path = File.expand_path("~/Downloads/all_counties_victims.csv")

CSV.open(file_path, "w") do |csv|
  # Header
  csv << [
    "municipio",
    "clave_inegi",
    "estado",
    "2018",
    "2019",
    "2020",
    "2021",
    "2022",
    "2023",
    "2024",
    "2025"
  ]

  County.includes(:state).order(:full_code).find_each do |county|
    state = county.state

    full_code =
      if county.full_code.present?
        county.full_code
      else
        "#{state&.code.to_s.rjust(2, '0')}#{county.code.to_s.rjust(3, '0')}"
      end

    row = [
      county.name,
      full_code,
      state&.shortname.to_s
    ]

    years.each do |year_name|
      year = year_map[year_name]

      count =
        if year.present?
          county.victims.merge(year.victims).count
        else
          0
        end

      row << count
    end

    csv << row
  end
end

puts "CSV generado en: #{file_path}"

nil