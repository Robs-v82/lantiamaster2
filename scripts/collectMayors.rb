require 'csv'
require_relative '../config/environment'

csv_path = Rails.root.join('scripts', 'historico_alcaldes_nombres_v10.csv')

mayor_role = Role.find_by(name: 'Alcalde')
if mayor_role.nil?
  puts "⚠️ No se encontró el rol 'Alcalde'."
  exit
end

last_name_key = nil
last_row = nil
skipped_duplicates = []

CSV.foreach(csv_path, headers: true) do |row|
  nombre = row['firstname'].to_s.strip
  ap1 = row['lastname1'].to_s.strip
  ap2 = row['lastname2'].to_s.strip
  raw_full_code = row['full_code'].to_s.strip
  full_code = raw_full_code.rjust(5, '0')

  name_key = "#{nombre}|#{ap1}|#{ap2}|#{full_code}"

  if name_key == last_name_key
    last_row['end_date'] = row['end_date']
    next
  end

  if last_row
    firstname  = last_row['firstname'].to_s.strip
    lastname1  = last_row['lastname1'].to_s.strip
    lastname2  = last_row['lastname2'].to_s.strip
    start_date = last_row['start_date']
    county_code = last_row['full_code'].to_s.strip.rjust(5, '0')

    # Validar duplicado estricto por nombre completo y start_date
    if Member.exists?(firstname: firstname, lastname1: lastname1, lastname2: lastname2, start_date: start_date)
      skipped_duplicates << "#{firstname} #{lastname1} #{lastname2} (#{start_date})"
    else
      county = County.find_by(full_code: county_code)
      if county.nil? || county.organizations.empty?
        puts "⚠️ No se encontró organización para county con full_code: #{county_code}"
      else
        begin
          Member.create!(
            firstname: firstname,
            lastname1: lastname1,
            lastname2: lastname2,
            start_date: start_date,
            end_date: last_row['end_date'],
            organization_id: county.organizations.first.id,
            role_id: mayor_role.id
          )
          puts "✅ Miembro creado: #{firstname} #{lastname1} #{lastname2} (#{start_date})"
        rescue => e
          puts "❌ Error creando miembro: #{e.message}"
        end
      end
    end
  end

  last_row = row
  last_name_key = name_key
end

# Procesar la última fila también
if last_row
  firstname  = last_row['firstname'].to_s.strip
  lastname1  = last_row['lastname1'].to_s.strip
  lastname2  = last_row['lastname2'].to_s.strip
  start_date = last_row['start_date']
  county_code = last_row['full_code'].to_s.strip.rjust(5, '0')

  if Member.exists?(firstname: firstname, lastname1: lastname1, lastname2: lastname2, start_date: start_date)
    skipped_duplicates << "#{firstname} #{lastname1} #{lastname2} (#{start_date})"
  else
    county = County.find_by(full_code: county_code)
    if county && county.organizations.any?
      begin
        Member.create!(
          firstname: firstname,
          lastname1: lastname1,
          lastname2: lastname2,
          start_date: start_date,
          end_date: last_row['end_date'],
          organization_id: county.organizations.first.id,
          role_id: mayor_role.id
        )
        puts "✅ Miembro creado: #{firstname} #{lastname1} #{lastname2} (#{start_date})"
      rescue => e
        puts "❌ Error creando último miembro: #{e.message}"
      end
    else
      puts "⚠️ No se encontró organización para county con full_code: #{county_code}"
    end
  end
end

# Reportar miembros omitidos
unless skipped_duplicates.empty?
  puts "\n⚠️ Miembros omitidos por duplicado:"
  skipped_duplicates.uniq.each do |name|
    puts " - #{name}"
  end
end
