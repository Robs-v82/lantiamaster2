# script_autoridades_filtradas.rb


autoridadesExpuestas = Member
  .joins(:hits).distinct.where(:involved=>false)

autoridadesExpuestasSinRel = autoridadesExpuestas.where(<<~SQL)
  NOT EXISTS (
    SELECT 1
    FROM member_relationships mr
    WHERE mr.member_a_id = members.id OR mr.member_b_id = members.id
  )
SQL

jn_notes = Note.reflect_on_association(:members).join_table

autoridadesExpuestasSinRelSinNotas = autoridadesExpuestasSinRel.where(<<~SQL)
  NOT EXISTS (
    SELECT 1
    FROM #{jn_notes} j
    WHERE j.member_id = members.id
  )
SQL

# many-to-many hits <-> members
autoridadesFinal = autoridadesExpuestasSinRelSinNotas
  # (A) Debe tener AL MENOS un hit asociado
  .where(<<~SQL)
    EXISTS (
      SELECT 1
      FROM hits_members hm
      WHERE hm.member_id = members.id
    )
  SQL
  # (B) No debe tener NINGÚN hit con link válido (no nulo)
  .where(<<~SQL)
    NOT EXISTS (
      SELECT 1
      FROM hits_members hm
      JOIN hits h ON h.id = hm.hit_id
      WHERE hm.member_id = members.id
        AND h.link IS NOT NULL
        -- AND TRIM(h.link) <> ''   -- descomenta si quieres excluir links vacíos
    )
  SQL

# autoridadesFinal = autoridadesFinal.order(:lastname1, :lastname2, :firstname, :id)

# --- SALIDA FINAL SIN ERRORES DE DISTINCT/ORDER BY ---

# Subquery de IDs únicos (sin ORDER)
base_ids = autoridadesExpuestasSinRelSinNotas
  .unscope(:order)
  .select("members.id")
  .distinct

# Conteo final
total = Member.where(id: base_ids).count

todos = Member
  .where(id: base_ids)
  .left_joins(:organization)
  .order("members.lastname1 ASC, members.lastname2 ASC, members.firstname ASC, members.id ASC")
  .pluck("members.id", "members.firstname", "members.lastname1", "members.lastname2", "organizations.name")

puts "Listado completo (id, nombre completo, organización):"
todos.each_with_index do |(id, fn, l1, l2, org_name), i|
  nombre = [fn, l1, l2].compact.join(" ")
  puts "#{i+1}. #{id} — #{nombre} — #{org_name || 'Sin organización'}"
puts "Total de miembros que cumplieron todas las condiciones: #{total}"

end