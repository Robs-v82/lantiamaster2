# Stats: members with hits in Veracruz
state = State.find_by(code: "30")
abort "Estado Veracruz no encontrado" unless state

veracruz_hit_ids = Hit.joins(town: { county: :state })
                      .where(states: { id: state.id })
                      .pluck(:id)

members = Member.joins(:hits)
                .where(hits: { id: veracruz_hit_ids })
                .includes(:organization, :criminal_link)
                .distinct

puts "\nTotal de personas con hits en Veracruz: #{members.count}\n"

# ─── TABLA 1: por criminal_role ───────────────────────────────────────────────
puts "\n" + "="*55
puts "TABLA 1 — Desglose por Criminal Rol"
puts "="*55

by_role = members.group_by { |m| m.criminal_role.presence || "(Sin rol criminal)" }
by_role_sorted = by_role.sort_by { |_k, v| -v.size }

printf "%-35s  %s\n", "Criminal Rol", "Total"
puts "-"*55
by_role_sorted.each do |rol, mems|
  printf "%-35s  %d\n", rol, mems.size
end
puts "-"*55
printf "%-35s  %d\n", "TOTAL", members.count

# ─── TABLA 2: por criminal_link / organización ────────────────────────────────
puts "\n" + "="*55
puts "TABLA 2 — Desglose por Criminal Link / Organización"
puts "="*55

by_org = Hash.new(0)
members.each do |m|
  key = if m.criminal_link.present?
          m.criminal_link.name
        elsif m.organization.present?
          m.organization.name
        else
          "(Sin organización)"
        end
  by_org[key] += 1
end
by_org_sorted = by_org.sort_by { |_k, v| -v }

printf "%-45s  %s\n", "Criminal Link / Organización", "Total"
puts "-"*55
by_org_sorted.each do |org, count|
  printf "%-45s  %d\n", org, count
end
puts "-"*55
printf "%-45s  %d\n", "TOTAL", members.count
