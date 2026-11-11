module DatasetsHelper

	def designated_ancestor_for(org)
		current = org&.parent
		while current.present?
		  return current if current.designation
		  current = current.parent
		end
		nil
	end

	# Valida que el hit tenga plain_text y que el apellido paterno del member aparezca en él.
	# Normaliza mayúsculas/minúsculas y acentos antes de comparar.
	def hit_text_matches_member?(hit, member)
		return false if member.nil? || hit.plain_text.blank? || member.lastname1.blank?
		normalize_for_match(hit.plain_text).include?(normalize_for_match(member.lastname1))
	end

	def normalize_for_match(str)
		str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.squish
	end

	ACCENT_CLASSES = { "a" => "aáàäâAÁÀÄÂ", "e" => "eéèëêEÉÈËÊ", "i" => "iíìïîIÍÌÏÎ", "o" => "oóòöôOÓÒÖÔ", "u" => "uúùüuÚÙÜÛ", "n" => "nñNÑ" }.freeze

	# Resalta en amarillo (mismo estilo de docs/compliance) el nombre y apellidos del member dentro del texto.
	# Si aparecen varias palabras seguidas del nombre, el espacio entre ellas también se resalta.
	# Ignora mayúsculas y acentos. Palabras de menos de 3 letras no se resaltan por sí solas.
	def highlight_member_names(text, member)
		escaped = ERB::Util.html_escape(text.to_s)
		words = [member.firstname, member.lastname1, member.lastname2].flat_map { |f| f.to_s.strip.split(/\s+/) }.reject { |w| w.length < 3 }
		return escaped if words.empty?
		sequences = []
		(0...words.length).each { |i| (i...words.length).each { |j| sequences << words[i..j] } }
		alternatives = sequences.sort_by { |seq| -seq.join(" ").length }.map { |seq| seq.map { |w| member_name_pattern(w) }.join('\s+') }
		pattern = Regexp.new("(?<!\\p{L})(" + alternatives.join("|") + ")(?!\\p{L})", Regexp::IGNORECASE)
		escaped.gsub(pattern) { %(<span style="background-color: #ffee58;">#{$1}</span>) }.html_safe
	end

	def member_name_pattern(token)
		token.split(/\s+/).map { |word|
			word.chars.map { |c|
				base = c.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
				if ACCENT_CLASSES[base]
					"[#{ACCENT_CLASSES[base]}]"
				else
					Regexp.escape(c)
				end
			}.join
		}.join('\s+')
	end

end
