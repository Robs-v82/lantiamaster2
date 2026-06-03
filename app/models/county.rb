class County < ApplicationRecord
	belongs_to :state
	belongs_to :city, optional: true
	has_many :county_aliases, dependent: :destroy
	has_many :towns
	has_many :organizations
	has_many :rackets, :through => :towns
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :leads, :through => :events
	has_many :detentions, :through => :events
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_many :sources, :through => :events
	has_many :appointments, dependent: :nullify
	serialize :comparison, Array

	# Validación robusta de código INEGI
	# Retorna: { county: County, method: String, confidence: String }
	# O: { county: nil, method: String, confidence: 'not_found', message: String }
	def self.validate_inegi(inegi_code, municipio_name = nil, estado_name = nil)
		result = {
			county: nil,
			method: nil,
			confidence: nil,
			search_log: []
		}

		return result if inegi_code.blank? && municipio_name.blank?

		# 1. BÚSQUEDA POR CÓDIGO INEGI EXACTO
		if inegi_code.present? && inegi_code.match?(/^\d{5}$/)
			county = County.where(code: inegi_code).first
			if county
				result[:county] = county
				result[:method] = 'exact_code'
				result[:confidence] = 'high'
				result[:search_log] << "✓ Encontrado por código exacto: #{inegi_code}"
				return result
			end
			result[:search_log] << "✗ Código #{inegi_code} no existe en DB"
		end

		# 2. BÚSQUEDA POR CÓDIGO + ESTADO (validación cruzada)
		if inegi_code.present? && estado_name.present?
			state = State.where("LOWER(name) = ?", estado_name.downcase).first
			if state
				county = state.counties.where(code: inegi_code).first
				if county
					result[:county] = county
					result[:method] = 'code_with_state'
					result[:confidence] = 'high'
					result[:search_log] << "✓ Validado: código #{inegi_code} en estado #{estado_name}"
					return result
				end
				result[:search_log] << "✗ Código #{inegi_code} no existe en estado #{estado_name}"
			end
		end

		# 3. BÚSQUEDA POR NOMBRE NORMALIZADO
		if municipio_name.present?
			normalized = normalize_name(municipio_name)
			county = County.where("LOWER(REPLACE(REPLACE(name, 'á', 'a'), 'é', 'e')) LIKE ?", "%#{normalized}%").first
			if county
				result[:county] = county
				result[:method] = 'normalized_name'
				result[:confidence] = 'medium'
				result[:search_log] << "✓ Encontrado por nombre normalizado: #{municipio_name} → #{county.name}"
				return result
			end
			result[:search_log] << "✗ Municipio '#{municipio_name}' no encontrado por nombre"
		end

		# 4. BÚSQUEDA POR ALIAS COMÚN
		if municipio_name.present?
			normalized = normalize_name(municipio_name)
			alias_record = CountyAlias.where("LOWER(REPLACE(REPLACE(alias_name, 'á', 'a'), 'é', 'e')) LIKE ?", "%#{normalized}%").first
			if alias_record
				result[:county] = alias_record.county
				result[:method] = 'alias'
				result[:confidence] = 'high'
				result[:search_log] << "✓ Encontrado por alias: #{municipio_name} → #{alias_record.county.name}"
				return result
			end
			result[:search_log] << "✗ Alias '#{municipio_name}' no encontrado"
		end

		# 5. BÚSQUEDA POR ESTADO + NOMBRE (si ambos disponibles)
		if municipio_name.present? && estado_name.present?
			state = State.where("LOWER(name) = ?", estado_name.downcase).first
			if state
				normalized = normalize_name(municipio_name)
				county = state.counties.where("LOWER(name) LIKE ?", "%#{normalized}%").first
				if county
					result[:county] = county
					result[:method] = 'state_and_name'
					result[:confidence] = 'medium'
					result[:search_log] << "✓ Encontrado: #{estado_name} - #{municipio_name}"
					return result
				end
			end
		end

		# No encontrado
		result[:confidence] = 'not_found'
		result[:search_log] << "✗ No se pudo validar: INEGI=#{inegi_code}, Municipio=#{municipio_name}, Estado=#{estado_name}"

		result
	end

	private

	def self.normalize_name(name)
		name.to_s
			.downcase
			.tr('áéíóú', 'aeiou')
			.gsub(/[^a-z0-9\s]/, '')
			.gsub(/\s+/, ' ')
			.strip
	end
end


 