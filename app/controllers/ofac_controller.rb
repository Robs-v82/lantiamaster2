require 'csv'
require 'net/http'
require 'uri'
require 'json'

class OfacController < ApplicationController
  before_action :require_admin!

  # Cargar el executor del pipeline OFAC para acceso a los pasos
  def self.load_ofac_executor
    executor_path = Rails.root.join("scripts", "ofac_pipeline_executor.rb")
    load executor_path if File.exist?(executor_path)
  end

  load_ofac_executor

  def index
    puts "[OFAC DEBUG] Métodos definidos en OfacController:"
    self.class.instance_methods(false).each { |m| puts "  - #{m}" }
    @last_execution = session[:last_ofac_execution]
  end

  def execute
    begin
      # Obtener API keys necesarias y pasarlas al script
      ENV["SERPER_API_KEY"] = serper_api_key
      ENV["ANTHROPIC_API_KEY"] = anthropic_api_key

      # Ejecutar el script principal del pipeline OFAC
      script_path = Rails.root.join('scripts', 'ofac_pipeline_main.rb')

      # Capturar la salida del script
      output = `cd #{Rails.root} && ruby #{script_path} 2>&1`

      # Parsear la salida para extraer los datos de las tablas
      result = parse_ofac_output(output)

      if result[:success]
        # Obtener el Hit desde la BD para asegurar datos actualizados (sin "provisional")
        hit = Hit.find_by(id: result[:hit_id]) if result[:hit_id]

        if hit
          # Construir ubicación formateada desde la BD
          location = if hit.town.present?
                       "#{hit.town.county&.name}, #{hit.town.county&.state&.name}"
                     else
                       "N/A"
                     end

          # Usar datos del Hit en BD (sin "(provisional)")
          result[:hit][:date] = hit.date.to_s
          result[:hit][:location] = location
        end

        # Ejecutar PASO 8.5: Estimar Género
        gender_result = estimate_gender(result[:candidate])

        # Agregar género a result para incluir en respuesta JSON
        result[:gender] = gender_result[:gender]
        result[:gender_source] = gender_result[:source]
        result[:gender_confidence] = gender_result[:confidence]

        # Guardar en sesión para mostrar en index
        session[:last_ofac_execution] = {
          timestamp: Time.now,
          candidate: result[:candidate],
          hit: result[:hit],
          organization: result[:organization],
          alias_array: result[:alias_array],
          role: result[:role],
          gender: gender_result[:gender],
          gender_source: gender_result[:source],
          gender_confidence: gender_result[:confidence],
          plain_text_length: result[:plain_text_length]
        }

        response_data = {
          success: true,
          candidate: result[:candidate],
          firstname: result[:firstname],
          lastname1: result[:lastname1],
          lastname2: result[:lastname2],
          hit: result[:hit],
          organization: result[:organization],
          alias_array: result[:alias_array],
          role: result[:role],
          gender: result[:gender] || "DESCONOCIDO",
          gender_source: result[:gender_source] || "fallback",
          gender_confidence: result[:gender_confidence] || 0,
          plain_text_length: result[:plain_text_length],
          plain_text_fragment: result[:plain_text_fragment]
        }
        Rails.logger.info("[OfacController] ✅ PIPELINE EXITOSO")
        Rails.logger.info("[OfacController] Candidato: #{result[:candidate]}")
        Rails.logger.info("[OfacController] Nombres extraídos: #{result[:firstname]} | #{result[:lastname1]} | #{result[:lastname2]}")
        Rails.logger.info("[OfacController] Hit ID: #{response_data[:hit][:id] rescue 'N/A'}")
        Rails.logger.info("[OfacController] Hit Link: #{response_data[:hit][:link] rescue 'N/A'}")
        Rails.logger.info("[OfacController] Organización Identificada: #{response_data[:organization]&.name || response_data[:organization]}")
        Rails.logger.info("[OfacController] Género: #{response_data[:gender]} (confianza: #{response_data[:gender_confidence]}%)")
        render json: response_data
      else
        error_msg = result[:error] || "Error ejecutando el pipeline OFAC"
        Rails.logger.error("[OfacController#execute] Pipeline falló: #{error_msg}")
        render json: {
          success: false,
          error: error_msg
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("[OfacController#execute] #{e.class} - #{e.message}")
      render json: {
        success: false,
        error: "Error ejecutando OFAC: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  private

  def parse_ofac_output(output)
    begin
      # Verificar si el script ejecutó exitosamente
      if output.include?("PASOS 1-9 COMPLETADOS EXITOSAMENTE")

        # Extraer datos del candidato
        candidate_match = output.match(/Candidato:\s*(.+?)(?:\n|$)/)
        candidate_name = candidate_match ? candidate_match[1].strip : "Desconocido"

        # Extraer Hit ID
        hit_id_match = output.match(/Hit ID:\s*(\d+)/)
        hit_id = hit_id_match ? hit_id_match[1] : nil

        # Extraer título del Hit
        title_match = output.match(/Título:\s*(.+?)\.{3}/)
        hit_title = title_match ? title_match[1].strip : "Desconocido"

        # Extraer fecha
        date_match = output.match(/Fecha:\s*(\d{4}-\d{2}-\d{2})/)
        date = date_match ? date_match[1] : "N/A"
        Rails.logger.info("[OfacController] Extracted date: #{date} (match: #{date_match.inspect})")

        # Extraer ubicación
        location_match = output.match(/Ubicación:\s*(.+?)(?:\n|$)/)
        location = location_match ? location_match[1].strip : "N/A"

        # Extraer organización
        organization_match = output.match(/Organización:\s*(.+?)\s*\(Confianza/)
        organization = organization_match ? organization_match[1].strip : "N/A"

        # Extraer Alias
        alias_match = output.match(/Alias:\s*(.+?)(?:\n|$)/)
        alias_text = alias_match ? alias_match[1].strip : "No identificados"
        alias_array = alias_text == "No identificados" ? [] : alias_text.split(/[,;]/).map(&:strip)

        # Extraer Rol
        role_match = output.match(/Rol:\s*(.+?)\s*\(Confianza/)
        role = role_match ? role_match[1].strip : "Sin definir"

        # Extraer Legacy ID del Hit
        legacy_id_match = output.match(/Legacy ID\s*│\s*([A-Z0-9_]+)/)
        legacy_id = legacy_id_match ? legacy_id_match[1].strip : nil

        # Extraer Link
        link_match = output.match(/Fuente \(Link\)\s*│\s*(.+?)(?:\n|$)/)
        link = link_match ? link_match[1].strip : nil

        # Extraer Plain text length
        plain_text_match = output.match(/Plain text válido\s*│\s*✅\s*(\d+)\s*caracteres/)
        plain_text_length = plain_text_match ? plain_text_match[1].to_i : 0

        # Extraer fragmento del plain text
        fragment_match = output.match(/Fragmento inicial:\s*(.+?)\.\.\./m)
        plain_text_fragment = fragment_match ? fragment_match[1].strip : ""

        # Extraer componentes del nombre ya parseados por el script
        firstname_match = output.match(/- Firstname:\s*(.+?)(?:\n|$)/)
        firstname = firstname_match ? firstname_match[1].strip : ""

        lastname1_match = output.match(/- Lastname1:\s*(.+?)(?:\n|$)/)
        lastname1 = lastname1_match ? lastname1_match[1].strip : ""

        lastname2_match = output.match(/- Lastname2:\s*(.+?)(?:\n|$)/)
        lastname2 = lastname2_match ? lastname2_match[1].strip : ""

        {
          success: true,
          candidate: candidate_name,
          firstname: firstname,
          lastname1: lastname1,
          lastname2: lastname2,
          hit_id: hit_id,
          hit: {
            id: hit_id,
            title: hit_title,
            date: date,
            location: location,
            legacy_id: legacy_id,
            link: link,
            plain_text_length: plain_text_length,
            fragment: plain_text_fragment
          },
          organization: organization,
          alias_array: alias_array,
          role: role,
          plain_text_length: plain_text_length,
          plain_text_fragment: plain_text_fragment
        }
      else
        error_msg = extract_error_from_output(output)
        Rails.logger.error("[OfacController#parse_ofac_output] Pipeline no completó exitosamente")
        Rails.logger.error("[OfacController#parse_ofac_output] Output últimas 500 chars: #{output[-500..-1]}")
        {
          success: false,
          error: error_msg || "El pipeline OFAC no completó exitosamente"
        }
      end
    rescue => e
      Rails.logger.error("[OfacController#parse_ofac_output] #{e.class} - #{e.message}")
      {
        success: false,
        error: "Error parseando la salida: #{e.message}"
      }
    end
  end

  def extract_error_from_output(output)
    if output.include?("No hay candidatos OFAC disponibles")
      "No hay candidatos OFAC disponibles para procesar"
    elsif output.include?("No se encontró Hit válido")
      "No se encontró artículo válido en la búsqueda"
    elsif output.include?("PASO 6 FALLÓ")
      "Validación fallida en PASO 6 - Requisitos críticos no cumplidos"
    elsif output.include?("ERROR")
      error_match = output.match(/ERROR:\s*(.+?)(?:\n|$)/)
      error_match ? error_match[1].strip : "Error no especificado en el pipeline"
    else
      nil
    end
  end

  public

  # Estimar género del candidato (Búsqueda en CSV + Claude)
  def estimate_gender(candidate)
    firstname = candidate.to_s.split.first.to_s.strip

    Rails.logger.info("[estimate_gender] Estimando para: '#{firstname}'")

    # 1. Buscar en CSV
    gender_from_csv = search_gender_in_csv(firstname)
    if gender_from_csv
      Rails.logger.info("[estimate_gender] ✓ CSV: #{gender_from_csv}")
      return { gender: gender_from_csv, source: "csv", confidence: 100 }
    end

    # 2. Usar Claude
    gender_from_claude = estimate_gender_with_claude(firstname)
    if gender_from_claude
      Rails.logger.info("[estimate_gender] ✓ Claude: #{gender_from_claude}")
      return { gender: gender_from_claude, source: "claude", confidence: 85 }
    end

    # 3. Heurística simple si Claude falla
    gender_simple = simple_gender_heuristic(firstname)
    if gender_simple != "DESCONOCIDO"
      Rails.logger.info("[estimate_gender] ✓ Heurística: #{gender_simple}")
      return { gender: gender_simple, source: "heuristic", confidence: 60 }
    end

    # 4. Fallback
    Rails.logger.warn("[estimate_gender] ✗ No determinado para '#{firstname}'")
    { gender: "DESCONOCIDO", source: "fallback", confidence: 0 }
  end

  def search_gender_in_csv(firstname)
    csv_path = Rails.root.join("scripts", "names_by_gender.csv")
    return nil unless File.exist?(csv_path)

    firstname_normalized = firstname.downcase.strip

    CSV.foreach(csv_path, headers: true) do |row|
      csv_name = row['firstname']&.downcase&.strip
      next unless csv_name == firstname_normalized

      gender_raw = row['genero_estimado']&.strip&.downcase
      case gender_raw
      when 'masculino'
        return 'MASCULINO'
      when 'femenino'
        return 'FEMENINO'
      when 'desconocido'
        return 'DESCONOCIDO'
      end
    end

    nil
  end

  def simple_gender_heuristic(firstname)
    # Heurística simple basada en terminaciones comunes en español
    name_lower = firstname.downcase.strip

    # Patrones típicamente femeninos
    feminine_endings = ['a', 'ina', 'ina', 'ela', 'ica']
    return 'FEMENINO' if feminine_endings.any? { |e| name_lower.end_with?(e) }

    # Patrones típicamente masculinos
    masculine_endings = ['o', 'or', 'ez', 'ito', 'ico']
    return 'MASCULINO' if masculine_endings.any? { |e| name_lower.end_with?(e) }

    # Por defecto
    'DESCONOCIDO'
  end

  def estimate_gender_with_claude(firstname)
    api_key = anthropic_api_key
    return nil if api_key.blank?

    prompt = %{
      Dado el nombre: "#{firstname}"

      Estima el género probable de una persona con este nombre en contexto hispanohablante.

      Responde SOLO con una de estas palabras, sin explicación:
      - MASCULINO
      - FEMENINO
      - DESCONOCIDO

      Si no estás seguro, responde: DESCONOCIDO
    }

    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'

    body = {
      model: 'claude-opus-5-5',
      max_tokens: 10,
      messages: [
        { role: 'user', content: prompt }
      ]
    }

    request.body = body.to_json

    begin
      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code == '200' && result['content']&.first
        gender_text = result['content'].first['text'].strip.upcase
        case gender_text
        when 'MASCULINO', 'FEMENINO', 'DESCONOCIDO'
          return gender_text
        end
      end
    rescue => e
      Rails.logger.error("[OfacController#estimate_gender_with_claude] #{e.class} - #{e.message}")
    end

    nil
  end

  # PASO 10: Descartar nombre OFAC
  def discard
    candidate = params[:candidate]

    if candidate.blank?
      return render json: { success: false, error: "Candidato no especificado" }, status: :unprocessable_entity
    end

    begin
      OfacCandidate.create!(
        ofac_name: candidate,
        status: 3,  # "not_found" enum
        notes: "Descartado por usuario en #{Time.now}"
      )

      render json: { success: true, message: "Nombre descartado exitosamente" }
    rescue => e
      Rails.logger.error("[OfacController#discard] #{e.class} - #{e.message}")
      render json: { success: false, error: "Error descartando nombre: #{e.message}" }, status: :unprocessable_entity
    end
  end

  # PASO 10: Cargar member (copia íntegra de datasets#create_easy_member adaptada)
  def create_member
    firstname = params[:firstname].to_s.strip
    lastname1 = params[:lastname1].to_s.strip
    lastname2 = params[:lastname2].to_s.strip

    # Procesar aliases igual que en easy_members (cadena separada por punto y coma)
    alias_raw = params[:alias_raw].to_s
    aliases = alias_raw
      .split(";")
      .map { |s| s.strip }
      .reject(&:blank?)
      .uniq

    Rails.logger.info("[OfacController#create_member] alias_raw: '#{alias_raw}'")
    Rails.logger.info("[OfacController#create_member] aliases procesados: #{aliases.inspect}")
    role_name = params[:role_name].to_s.strip
    organization_name = params[:organization].to_s.strip
    legacy_id = params[:legacy_id].to_s.strip
    provisional_gender = params[:provisional_gender].to_s.strip  # Género estimado del PASO 8.5

    begin
      # Obtener objeto Hit por legacy_id
      hit = Hit.find_by(legacy_id: legacy_id)
      unless hit.present?
        return render json: { success: false, error: "Hit no encontrado" }, status: :unprocessable_entity
      end

      # Obtener objeto Role por nombre
      role = Role.find_by(name: role_name)
      unless role.present?
        return render json: { success: false, error: "Rol inválido" }, status: :unprocessable_entity
      end

      # Obtener objeto Organization por nombre
      org = Organization.find_by(name: organization_name)
      unless org.present?
        return render json: { success: false, error: "Organización inválida" }, status: :unprocessable_entity
      end

      # Buscar member existente (exacto o similar)
      match = Member.where(firstname: firstname, lastname1: lastname1, lastname2: lastname2).find do |m|
        m.firstname == firstname && m.lastname1 == lastname1 && m.lastname2 == lastname2
      end

      # Lookup tables para criminal_role (copiado de datasets_controller)
      lookup_true = {
        "Líder" => "Líder",
        "Sicario" => "Miembro",
        "Narcomenudista" => "Miembro",
        "Jefe de sicarios" => "Miembro",
        "Jefe operativo" => "Miembro",
        "Jefe de plaza" => "Miembro",
        "Jefe de célula" => "Miembro",
        "Jefe regional" => "Miembro",
        "Extorsionador" => "Miembro",
        "Traficante o distribuidor" => "Miembro",
        "Operador" => "Miembro",
        "Socio" => "Socio",
        "Abogado" => "Socio",
        "Manager" => "Socio",
        "Artista" => "Socio",
        "Músico" => "Socio",
        "Autoridad cooptada" => "Autoridad vinculada",
        "Regidor" => "Autoridad vinculada",
        "Policía" => "Autoridad vinculada",
        "Militar" => "Autoridad vinculada",
        "Alcalde" => "Autoridad vinculada",
        "Gobernador" => "Autoridad vinculada",
        "Delegado estatal" => "Autoridad vinculada",
        "Secretario de Seguridad" => "Autoridad vinculada",
        "Sin definir" => nil
      }.freeze

      involved_value = [
        "Líder", "Operador", "Autoridad cooptada", "Socio",
        "Sicario", "Narcomenudista", "Jefe de sicarios", "Jefe operativo",
        "Jefe de plaza", "Jefe de célula", "Jefe regional",
        "Extorsionador", "Traficante o distribuidor"
      ].include?(role_name)

      criminal_role_value = lookup_true[role_name] if involved_value

      if match.present?
        # Member existente: actualizar + sumar hit
        case role_name
        when "Líder", "Operador", "Socio"
          match.update(role: role, involved: true)
        when "Autoridad cooptada"
          match.update(involved: true)
          match.update(criminal_link: org)
        end

        if aliases.any?
          current_aliases = Array(match.alias).map(&:to_s)
          merged = (current_aliases + aliases).map(&:strip).reject(&:blank?).uniq
          match.update(alias: merged)
        end

        match.hits << hit unless match.hits.exists?(hit.id)
        member = match
      else
        # Member nuevo: crear completo
        # Usar género provisional del PASO 8.5 si no hay género asignado
        member_gender = provisional_gender.blank? ? nil : provisional_gender

        member = Member.create!(
          firstname: firstname,
          lastname1: lastname1,
          lastname2: lastname2,
          alias: aliases,
          organization: org,
          role: role,
          involved: involved_value,
          criminal_role: criminal_role_value,
          gender: member_gender,
          criminal_link_id: org&.criminal_link_id
        )

        member.hits << hit
      end

      # Ejecutar script de actualización OFAC para este Member específico
      script_path = Rails.root.join("scripts", "ofac_update_member.rb")
      Rails.logger.info("[OfacController#create_member] Ejecutando ofac_update_member.rb para Member #{member.id}...")
      system("cd #{Rails.root} && bundle exec rails runner #{script_path} #{member.id} >> log/ofac_update.log 2>&1")
      Rails.logger.info("[OfacController#create_member] ofac_update_member.rb completado")

      # Limpiar sesión
      session[:last_ofac_execution] = nil

      render json: {
        success: true,
        message: "Member #{match.present? ? 'actualizado' : 'creado'} exitosamente",
        member_id: member.id
      }
    rescue => e
      Rails.logger.error("[OfacController#create_member] #{e.class} - #{e.message}")
      render json: {
        success: false,
        error: "Error creando member: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def anthropic_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
    ENV["ANTHROPIC_API_KEY"].presence ||
      Rails.application.credentials.dig(:anthropic, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end

  def serper_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "serper_api_key").expand_path
    ENV["SERPER_API_KEY"].presence ||
      Rails.application.credentials.dig(:serper, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end

  private

  # Métodos privados para parse y error handling
  # (ninguno actualmente, pero reservado para futuros métodos privados)

end
