require "csv"

headers = [
  "Member.id",
  "Organization.name (o criminal_link si aplica)",
  "Member.firstname",
  "Member.lastname1",
  "Member.lastname2",
  "Member.alias",
  "Última detención (event_date)"
]

rows = Member
  .joins("JOIN roles ON roles.id = members.role_id")
  .joins("JOIN hits_members hm ON hm.member_id = members.id")
  .joins("LEFT JOIN organizations org ON org.id = members.organization_id")
  .joins("LEFT JOIN organizations org_cl ON org_cl.id = members.criminal_link_id")
  .joins("LEFT JOIN detentions d ON d.id = members.detention_id")
  .joins("LEFT JOIN events e ON e.id = d.event_id")
  .distinct
  .pluck(
    "members.id",
    "COALESCE(org_cl.name, org.name)",  # Prioriza criminal_link si existe
    "members.firstname",
    "members.lastname1",
    "members.lastname2",
    "members.alias",
    "e.event_date"
  )

normalized = rows.map do |mid, org, fn, ln1, ln2, al, det_date|
  aliases = (al || "").to_s
                .gsub(/\r?\n/, ";")   # saltos de línea → ;
                .gsub(/[,\|]/, ";")   # comas o barras → ;
                .split(";")
                .map(&:strip)
                .reject(&:blank?)
                .join(";")
  [mid, org, fn, ln1, ln2, aliases, det_date&.to_date&.iso8601]
end

# --- Salida CSV a consola ---
puts CSV.generate(force_quotes: true) { |csv|
  csv << headers
  normalized.each { |r| csv << r }
}

# --- (Opcional) Guardar a archivo CSV ---
# csv_path = Rails.root.join("tmp", "leaders_with_hits.csv")
# CSV.open(csv_path, "w", force_quotes: true) do |csv|
#   csv << headers
#   normalized.each { |r| csv << r }
# end
# puts "CSV generado en: #{csv_path}"
