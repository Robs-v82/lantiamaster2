# Paso 1: Lista de medios nacionales
nationalMedia = [
  "infobae.com",
  "jornada.com.mx",
  "oem.com.mx",
  "lasillarota.com",
  "milenio.com",
  "proceso.com.mx",
  "excelsior.com.mx",
  "elfinanciero.com.mx",
  "eluniversal.com.mx",
  "eleconomista.com.mx",
  "sinembargo.mx",
  "aristeguinoticias.com",
  "reforma.com",
  "univision.com",
  "latinus.us"
]

# Paso 2: Actualizar cada hit
puts "⏳ Actualizando nacionalidad de hits..."
Hit.find_each do |hit|
  domain = hit.link.to_s.match(/https?:\/\/(?:www\.)?([^\/]+)/).to_a[1]
  is_national = nationalMedia.include?(domain)
  hit.update_column(:national, is_national)
end
puts "✅ Hits actualizados."

# Paso 3: Obtener miembros con al menos un hit
keyMembers = Member.joins(:hits).distinct

# Paso 4: Evaluar media_score de cada miembro
puts "⏳ Evaluando media_score..."
keyMembers.find_each do |member|
  hits = member.hits
  media_score_value = hits.size >= 2 && hits.any? { |h| h.national }
  member.update_column(:media_score, media_score_value)
end
puts "✅ media_score actualizado para miembros clave."
