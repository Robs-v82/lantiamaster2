require 'csv'
require_relative '../config/environment'

csv_path = Rails.root.join('scripts', 'historico_alcaldes_nombres_v10.csv')
updated = 0
not_found = []

CSV.foreach(csv_path, headers: true) do |row|
  firstname  = row['firstname'].to_s.strip
  lastname1  = row['lastname1'].to_s.strip
  lastname2  = row['lastname2'].to_s.strip
  full_code  = row['full_code'].to_s.strip.rjust(5, '0')

  start_date = row['Inicio'].to_s.strip
  end_date   = row['Conclusión'].to_s.strip

  county = County.find_by(full_code: full_code)
  organization = county&.organizations&.first

  if organization
    member = Member.find_by(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      organization_id: organization.id
    )

    if member
      member.update(start_date: start_date, end_date: end_date)
      updated += 1
      puts "✅ Actualizado: #{firstname} #{lastname1} (#{start_date} - #{end_date})"
    else
      not_found << "#{firstname} #{lastname1} #{lastname2} | #{full_code}"
    end
  else
    not_found << "ORG no encontrada para código: #{full_code}"
  end
end

