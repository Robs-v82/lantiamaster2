# 👉 DEMO: ejemplo de entrada
myMembers = Member.joins(:hits).distinct
corregidos = []

# Define esta función una sola vez en la consola de Rails
myMembers.each do |member|
  fn = member.firstname.to_s.strip
  ln1 = member.lastname1.to_s.strip
  ln2 = member.lastname2.to_s.strip

    if fn.split.size == 1 && ln1.split.size == 1 && ln2.split.size == 2
      # Heurística aplicada
      nuevo_fn = "#{fn} #{ln1}"
      nuevo_ln1, nuevo_ln2 = ln2.split

      # Mostrar log de lo que va a cambiar
      puts "✏️ Corrigiendo ID #{member.id}:"
      puts "   🔹 Antes:  #{fn} | #{ln1} | #{ln2}"
      puts "   ✅ Después: #{nuevo_fn} | #{nuevo_ln1} | #{nuevo_ln2}"

      # Aplicar cambios
      member.update(
        firstname: nuevo_fn,
        lastname1: nuevo_ln1,
        lastname2: nuevo_ln2
      )
      corregidos << member.id
    end
  end

puts "\n✅ Correcciones aplicadas a #{corregidos.size} miembros: #{corregidos.join(', ')}"




