module DatasetsHelper

	  def normalize_for_match(s)
	    I18n.transliterate(s.to_s).downcase
	  end

	  # Resalta términos en HTML-safe (usa sanitize en la vista)
	  def highlight_terms_html(text, terms)
	    return "" if text.blank?

	    safe_text = ERB::Util.html_escape(text.to_s)

	    terms = Array(terms).map(&:to_s).map(&:strip).reject(&:blank?)
	    return safe_text if terms.empty?

	    # Ordenar por longitud desc para evitar que "Juan" rompa "Juan Carlos"
	    terms = terms.sort_by { |t| -t.length }

	    # Regex sobre texto escapado; "i" para case-insensitive
	    rx = Regexp.union(terms.map { |t| Regexp.new(Regexp.escape(t), Regexp::IGNORECASE) })

	    safe_text.gsub(rx) do |m|
	      %Q(<span style="background-color:#ffee58;">#{m}</span>)
	    end
	  end

	  # Extrae ~N palabras alrededor de la primera coincidencia (fullname o lastname1)
	  def excerpt_around_term(text, term, total_words: 90)
	    return nil if text.blank? || term.blank?

	    words = text.to_s.split(/\s+/)
	    return nil if words.empty?

	    # Buscar índice aproximado de coincidencia en palabras (normalizado)
	    norm_term = normalize_for_match(term)
	    norm_words = words.map { |w| normalize_for_match(w) }

	    # Intento 1: encontrar palabra que "contenga" el término (útil si term es apellido)
	    idx = norm_words.find_index { |w| w.include?(norm_term) }

	    # Intento 2: buscar el término en el texto completo y mapear a palabra cercana
	    if idx.nil?
	      norm_text = normalize_for_match(text)
	      pos = norm_text.index(norm_term)
	      return nil if pos.nil?

	      # Aproximación: usar conteo de espacios hasta pos
	      prefix = norm_text[0...pos]
	      approx_word = prefix.split(/\s+/).length
	      idx = [approx_word, words.length - 1].min
	    end

	    half = (total_words / 2.0).floor
	    start_i = [idx - half, 0].max
	    end_i   = [start_i + total_words - 1, words.length - 1].min
	    start_i = [end_i - total_words + 1, 0].max

	    words[start_i..end_i].join(" ")
	  end

end
