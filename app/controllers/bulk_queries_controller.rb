require 'csv'

class BulkQueriesController < ApplicationController
  include MonthlyQueryLimits
  include RoleClassifier

  before_action :authenticate_bulk_access

  def index
  end

  def upload_csv
    file = params[:file]

    if file.blank?
      return render json: { success: false, message: "Por favor, selecciona un archivo CSV." }
    end

    begin
      # Leer headers primero para validación
      headers_raw = []
      CSV.foreach(file.path, headers: true, encoding: "bom|utf-8") do |row|
        headers_raw = row.headers
        break
      end

      if headers_raw.empty?
        return render json: { success: false, message: "El archivo CSV no tiene headers." }
      end

      # Normalizar headers (español → inglés)
      headers_normalized = normalize_headers(headers_raw)
      header_validation = validate_csv_headers(headers_normalized)

      if !header_validation[:valid]
        return render json: { success: false, message: header_validation[:message] }
      end

      # Leer y procesar CSV con headers normalizados
      csv_rows = []
      CSV.foreach(file.path, headers: headers_normalized, encoding: "bom|utf-8") do |row|
        csv_rows << row.to_h.transform_keys(&:to_sym)
      end

      if csv_rows.empty?
        return render json: { success: false, message: "El archivo CSV está vacío (solo contiene headers)." }
      end

      # Validar estructura y contar filas efectivas
      effective_queries = []
      invalid_rows = []

      csv_rows.each_with_index do |row, index|
        reference = row[:reference]&.strip

        # Validar que tenga referencia
        if reference.blank?
          invalid_rows << {
            index: index + 1,
            reason: "El campo 'referencia' no puede estar vacío",
            reference: "",
            name: nil,
            firstname: row[:firstname]&.strip,
            lastname1: row[:lastname1]&.strip,
            lastname2: row[:lastname2]&.strip,
            mode: row[:name].present? ? :name : :segmented
          }
          next
        end

        # Dos modos: nombre completo o nombre propio+apellido paterno+apellido materno
        if row[:name].present?
          name = row[:name].to_s.strip
          if name.blank?
            invalid_rows << {
              index: index + 1,
              reason: "El campo 'nombre completo' no puede estar vacío",
              reference: reference,
              name: name,
              firstname: nil,
              lastname1: nil,
              lastname2: nil,
              mode: :name
            }
            next
          elsif name.length < 4
            invalid_rows << {
              index: index + 1,
              reason: "El campo 'nombre completo' debe tener mínimo 4 caracteres",
              reference: reference,
              name: name,
              firstname: nil,
              lastname1: nil,
              lastname2: nil,
              mode: :name
            }
            next
          end
          effective_queries << { mode: :name, name: name, reference: reference, row_index: index + 1 }
        else
          firstname = row[:firstname]&.strip
          lastname1 = row[:lastname1]&.strip
          lastname2 = row[:lastname2]&.strip

          # Detectar cuál campo es inválido y generar mensaje específico
          reason = nil
          if firstname.blank?
            reason = "El campo 'nombre propio' no puede estar vacío"
          elsif firstname.length < 2
            reason = "El campo 'nombre propio' debe tener mínimo 2 caracteres"
          elsif lastname1.blank?
            reason = "El campo 'apellido paterno' no puede estar vacío"
          elsif lastname1.length < 2
            reason = "El campo 'apellido paterno' debe tener mínimo 2 caracteres"
          elsif lastname2.blank?
            reason = "El campo 'apellido materno' no puede estar vacío"
          elsif lastname2.length < 2
            reason = "El campo 'apellido materno' debe tener mínimo 2 caracteres"
          end

          if reason.present?
            invalid_rows << {
              index: index + 1,
              reason: reason,
              reference: reference,
              name: nil,
              firstname: firstname,
              lastname1: lastname1,
              lastname2: lastname2,
              mode: :segmented
            }
            next
          end

          effective_queries << { mode: :segmented, firstname: firstname, lastname1: lastname1, lastname2: lastname2, reference: reference, row_index: index + 1 }
        end
      end

      if effective_queries.empty?
        return render json: { success: false, message: "No hay consultas válidas en el archivo." }
      end

      # Validar créditos
      user = User.find_by(id: session[:user_id])

      # Crear BulkQueryRun para esta sesión de carga
      bulk_query_run = BulkQueryRun.create!(
        user: user,
        csv_filename: file.original_filename,
        invalid_rows_data: [],
        valid_rows_data: [],
        summary_stats: {}
      )
      suscription = set_suscription(user)
      info = consultas_en_periodo(user)
      remaining = suscription[:points] - info[:total_org]

      if effective_queries.size > remaining
        return render json: {
          success: false,
          message: "No tienes consultas suficientes. Necesitas #{effective_queries.size} pero solo tienes #{remaining} disponibles. Escribe a contacto@lantiaintelligence.com para contratar más consultas.",
          meta: {
            required: effective_queries.size,
            available: remaining,
            plan: suscription[:level]
          }
        }
      end

      # Procesar consultas
      queries_results = []

      effective_queries.each do |query_data|
        if query_data[:mode] == :name
          qp = { name: query_data[:name] }
        else
          qp = {
            firstname: query_data[:firstname],
            lastname1: query_data[:lastname1],
            lastname2: query_data[:lastname2]
          }
        end

        # Procesar búsqueda similar al método search en Api::V1::MembersController
        homo_score = query_data[:mode] == :name ? compute_name_score(query_data[:name]) : compute_homo_score(query_data[:firstname], query_data[:lastname1], query_data[:lastname2])

        input_name = query_data[:mode] == :name ? normalize(query_data[:name]) : nil
        input_firstname = query_data[:mode] == :name ? nil : normalize(query_data[:firstname])
        input_lastname1 = query_data[:mode] == :name ? nil : normalize(query_data[:lastname1])
        input_lastname2 = query_data[:mode] == :name ? nil : normalize(query_data[:lastname2])

        # Búsqueda en base de datos
        base_scope = Member.joins(:hits).distinct

        prefilter_tokens = if input_name.present?
          toks = input_name.split(/\s+/).map(&:strip).map(&:downcase)
          toks.select { |t| t.length >= 4 }.sort_by { |t| -t.length }.first(2)
        else
          toks = [input_lastname1, input_lastname2].compact.map(&:strip).map(&:downcase)
          toks.select { |t| t.length >= 2 }.first(2)
        end

        conditions = []
        binds = {}

        prefilter_tokens.each_with_index do |tok, idx|
          key = :"q#{idx}"
          binds[key] = "%#{tok}%"
          conditions << (
            "LOWER(members.firstname) LIKE :#{key} OR LOWER(members.lastname1) LIKE :#{key} OR LOWER(members.lastname2) LIKE :#{key} OR LOWER(members.alias) LIKE :#{key} OR " \
            "LOWER(fake_identities.firstname) LIKE :#{key} OR LOWER(fake_identities.lastname1) LIKE :#{key} OR LOWER(fake_identities.lastname2) LIKE :#{key}"
          )
        end

        prefiltered_scope = if conditions.any?
          base_scope
            .left_joins(:fake_identities)
            .where("(#{conditions.map { |c| "(#{c})" }.join(" OR ")})", **binds)
            .distinct
        else
          base_scope
        end

        candidates = prefiltered_scope.select(:id, :firstname, :lastname1, :lastname2, :alias).preload(:fake_identities).to_a

        potential_match_ids = candidates.filter_map do |member|
          next nil if member.firstname.blank? && member.lastname1.blank? && member.lastname2.blank? &&
                      member.fake_identities.none? { |fi| fi.firstname.present? || fi.lastname1.present? || fi.lastname2.present? }

          if input_name.present?
            member_full = normalize(member.fullname)
            real_match = match?(input_name, member_full)

            fake_match = member.fake_identities.any? do |fi|
              next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?
              fi_full = normalize(fi.fullname)
              match?(input_name, fi_full)
            end

            (real_match || fake_match) ? member.id : nil
          else
            real_match =
              match?(input_firstname, normalize(member.firstname)) &&
              match?(input_lastname1, normalize(member.lastname1)) &&
              match?(input_lastname2, normalize(member.lastname2))

            fake_match = member.fake_identities.any? do |fi|
              next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?

              match?(input_firstname, normalize(fi.firstname)) &&
              match?(input_lastname1, normalize(fi.lastname1)) &&
              match?(input_lastname2, normalize(fi.lastname2))
            end

            (real_match || fake_match) ? member.id : nil
          end
        end

        # Fallback si no hay resultados
        if potential_match_ids.empty? && prefilter_tokens.present?
          candidates = base_scope.select(:id, :firstname, :lastname1, :lastname2, :alias).preload(:fake_identities).to_a

          potential_match_ids = candidates.filter_map do |member|
            next nil if member.firstname.blank? && member.lastname1.blank? && member.lastname2.blank? &&
                        member.fake_identities.none? { |fi| fi.firstname.present? || fi.lastname1.present? || fi.lastname2.present? }

            if input_name.present?
              member_full = normalize(member.fullname)
              real_match = match?(input_name, member_full)

              fake_match = member.fake_identities.any? do |fi|
                next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?
                fi_full = normalize(fi.fullname)
                match?(input_name, fi_full)
              end

              (real_match || fake_match) ? member.id : nil
            else
              real_match =
                match?(input_firstname, normalize(member.firstname)) &&
                match?(input_lastname1, normalize(member.lastname1)) &&
                match?(input_lastname2, normalize(member.lastname2))

              fake_match = member.fake_identities.any? do |fi|
                next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?

                match?(input_firstname, normalize(fi.firstname)) &&
                match?(input_lastname1, normalize(fi.lastname1)) &&
                match?(input_lastname2, normalize(fi.lastname2))
              end

              (real_match || fake_match) ? member.id : nil
            end
          end
        end

        result_count = potential_match_ids.size

        # Guardar query en BD
        dataset_last_updated_at = Member.maximum(:updated_at)
        query_record = Query.create!(
          firstname: qp[:firstname],
          lastname1: qp[:lastname1],
          lastname2: qp[:lastname2],
          homo_score: homo_score,
          outcome: potential_match_ids,
          search: Member.joins(:hits).distinct.count,
          user: user,
          member: user&.member,
          organization: user&.member&.organization,
          source: "bulk",
          status_code: 200,
          success: true,
          request_id: request.request_id,
          result_count: result_count,
          dataset_last_updated_at: dataset_last_updated_at,
          query_label: qp[:name].presence || [qp[:firstname], qp[:lastname1], qp[:lastname2]].compact.join(" "),
          bulk_query_run: bulk_query_run
        )

        queries_results << {
          reference: query_data[:reference],
          row_index: query_data[:row_index],
          result_count: result_count,
          query_id: query_record.id,
          mode: query_data[:mode],
          name: query_data[:mode] == :name ? query_data[:name] : nil,
          firstname: query_data[:mode] == :segmented ? query_data[:firstname] : nil,
          lastname1: query_data[:mode] == :segmented ? query_data[:lastname1] : nil,
          lastname2: query_data[:mode] == :segmented ? query_data[:lastname2] : nil,
          homo_score: homo_score
        }
      end

      # Generar resumen
      queries_with_matches = queries_results.count { |r| r[:result_count] > 0 }
      queries_without_matches = queries_results.count { |r| r[:result_count] == 0 }
      dataset_last_updated = Member.maximum(:updated_at)
      total_members = Member.joins(:hits).distinct.count
      final_remaining = suscription[:points] - (info[:total_org] + effective_queries.size)

      summary = {
        total_csv_rows: csv_rows.size,
        effective_queries: effective_queries.size,
        queries_with_matches: queries_with_matches,
        queries_without_matches: queries_without_matches,
        uploaded_at: Time.current.in_time_zone("America/Mexico_City").iso8601,
        dataset_last_updated_at: dataset_last_updated&.in_time_zone("America/Mexico_City")&.iso8601,
        total_members_in_db: total_members,
        plan: suscription[:level],
        credits_limit: suscription[:points],
        credits_used_before: info[:total_org],
        credits_used_this_batch: effective_queries.size,
        credits_remaining: final_remaining,
        invalid_rows_count: invalid_rows.size
      }

      # Limitar resultados a 200
      max_results = 200
      queries_results_limited = queries_results.first(max_results)
      invalid_rows_limited = invalid_rows.first(max_results)
      results_truncated = queries_results.size > max_results
      invalid_truncated = invalid_rows.size > max_results

      # Guardar datos en BulkQueryRun
      bulk_query_run.update!(
        invalid_rows_data: invalid_rows,
        valid_rows_data: queries_results,
        summary_stats: summary
      )

      render json: {
        success: true,
        summary: summary,
        results: queries_results_limited,
        results_truncated: results_truncated,
        results_total: queries_results.size,
        invalid_rows: invalid_rows_limited,
        invalid_truncated: invalid_truncated,
        invalid_total: invalid_rows.size,
        bulk_query_run_id: bulk_query_run.id
      }

    rescue => e
      Rails.logger.error("BulkQueries error: #{e.class} - #{e.message}")
      render json: { success: false, message: "Error al procesar archivo: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def bulk_query_pdf
    @myQuery = Query.find_by(id: params[:id])
    @user = User.find(@myQuery.user_id)
    @keyMembers = Member.where(id: @myQuery.outcome).includes(appointments: [:organization, :role])

    @last_updated_at = @myQuery&.dataset_last_updated_at
    @last_updated_at ||= @myQuery&.created_at

    h = ApplicationController.helpers

    pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
    pdf.font_families.update("Poppins" => {
      normal: Rails.root.join("app/assets/fonts/Poppins-Regular.ttf"),
      bold:   Rails.root.join("app/assets/fonts/Poppins-Bold.ttf")
    })
    pdf.font "Poppins"

    pdf.text "RESULTADOS", size: 16, style: :bold, align: :center, color: "33333C"
    pdf.move_down 20

    clave = "#{@user.member.firstname.first}#{@user.member.lastname1.first}-#{@user.member.organization_id}-#{@myQuery.id}"

    homonimo_label = case @myQuery.homo_score
      when 0...2 then "Baja"
      when 2...5 then "Media"
      when 5..10 then "Alta"
      else "Muy alta"
    end

    estimacion = case @myQuery.homo_score
      when 0...2 then "sólo 1"
      when 2...3 then "más de 2"
      when 3...4 then "más de 3"
      when 4...5 then "más de 4"
      when 5...6 then "más de 5"
      when 6...7 then "más de 6"
      when 7...8 then "más de 7"
      when 8...9 then "más de 8"
      when 9...10 then "más de 9"
      when 10...20 then "más de 10"
      when 20...30 then "más de 20"
      when 30...40 then "más de 30"
      when 40...50 then "más de 40"
      when 50...60 then "más de 50"
      when 60...70 then "más de 60"
      when 70...80 then "más de 70"
      when 80...90 then "más de 80"
      when 90...100 then "más de 90"
      when 100...200 then "más de 100"
      when 200...500 then "más de 200"
      when 500...1000 then "más de 500"
      else "más de 1000"
    end

    pdf.text "PARÁMETROS DE CONSULTA", size: 12, style: :bold, color: "EF4E50"
    pdf.move_down 8

    resumen_data = [
      ["ID:", clave],
      ["Fecha y hora:", @myQuery.created_at.in_time_zone("America/Mexico_City").strftime("%d/%m/%Y %H:%M")]
    ]

    name_mode = @myQuery.firstname.blank? && @myQuery.lastname1.blank? && @myQuery.lastname2.blank?

    if !name_mode
      resumen_data << ["Nombre(s):", @myQuery.firstname]
      resumen_data << ["Apellido Paterno:", @myQuery.lastname1]
      resumen_data << ["Apellido Materno:", @myQuery.lastname2]
    else
      resumen_data << ["Nombre consultado:", @myQuery.query_label.presence || "Sin especificar"]
    end

    resumen_data << ["Registros analizados:", @myQuery.search.to_s]
    resumen_data << ["Última actualización:",
      @last_updated_at ? @last_updated_at.in_time_zone("America/Mexico_City").strftime("%d/%m/%Y %H:%M") : "No disponible"
    ]

    unless name_mode || @myQuery.homo_score.blank?
      resumen_data << ["Probabilidad de homónimos:", homonimo_label]
      resumen_data << ["", "Se estima que hay #{estimacion} mexicano(s) adulto(s) con el nombre y apellidos consultados o alguna de sus variantes."]
    end

    pdf.table(resumen_data, cell_style: { size: 10, padding: [4, 6, 4, 6] }, column_widths: [170, 330]) do
      row(0..-1).columns(0).font_style = :bold
    end

    pdf.move_down 20

    pdf.text "RESULTADOS", size: 12, style: :bold, color: "EF4E50"
    pdf.move_down 10

    if @myQuery.outcome.blank?
      pdf.text "No identificamos registros de personas señaladas o personas expuestas que coincidan con los parámetros de consulta.", style: :bold, size: 10
      send_data pdf.render, filename: "#{clave}.pdf", type: "application/pdf", disposition: "attachment"
      return
    else
      total = @myQuery.outcome.size.to_i
      plural_n = total > 1 ? 'n' : ''
      plural_s = total > 1 ? 's' : ''
      pdf.text "Se identificó#{plural_n} #{total} registro#{plural_s} que coincide con los parámetros de consulta, según se detalla a continuación.", style: :bold, size: 10
      pdf.move_down 10
    end

    registros = @keyMembers.first(10)

    registros.each_with_index do |member, index|
      cartel = member.criminal_link.present? ? member.criminal_link : member.organization
      memberGroup = nil
      cr = member.criminal_role.to_s.strip.presence

      header_label =
        if registros.size == 1
          "REGISTRO ÚNICO"
        else
          case index
          when 0 then "PRIMER REGISTRO"
          when 1 then "SEGUNDO REGISTRO"
          when 2 then "TERCER REGISTRO"
          else "#{index + 1}º REGISTRO"
          end
        end

      pdf.fill_color "FFFFFF"
      pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 18
      pdf.fill_color "33333C"
      pdf.text header_label, align: :center, style: :bold
      pdf.move_down 6

      data = []
      data << ["Nombre(s):", member.firstname]
      data << ["Apellido paterno:", member.lastname1]
      data << ["Apellido materno:", member.lastname2]

      if member.alias.present? && member.alias.any?
        data << ["Alias:", member.alias.join(", ")]
      end

      if member.birthday?
        fecha_nac = if member.birthday_aprox?
                      "circa #{member.birthday.strftime('%Y')}"
                    else
                      member.birthday.strftime("%d/%m/%Y")
                    end
        data << ["Fecha de nacimiento:", fecha_nac]
      end

      if member.fake_identities.any?
        lista = member.fake_identities.map { |ide| "-#{ide.firstname} #{ide.lastname1} #{ide.lastname2}" }.join("\n")
        data << ["Identidades falsas/alternativas:", lista]
      end

      clasificacion = member.involved == false ? "Persona expuesta" : "Persona señalada"
      data << ["Clasificación:", clasificacion]

      pdf.table(data, cell_style: { size: 10, padding: [4, 6, 4, 6] }, column_widths: [170, 330]) do
        row(0..-1).columns(0).font_style = :bold
      end

      if member.ofac_designation? || member.ofac_ent_num.present?
        ofac_text = if member.ofac_designation?
                      "Persona incluida en listado OFAC."
                    else
                      "Registro relacionado con OFAC."
                    end

        if member.ofac_ent_num.present?
          ofac_text << "\nFolio OFAC: #{member.ofac_ent_num}"
        end

        pdf.table([["Designación OFAC:", ofac_text]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) do
          row(0).columns(0).font_style = :bold
        end
      end

      if member.titles.any?
        pdf.move_down 6
        member.titles.each do |title|
          cedula_rows = [
            ["Número:", title.legacy_id],
            ["Tipo:", title.type],
            ["Profesión:", title.profesion.to_s.titleize],
            ["Institución:", title.organization&.name],
            ["Año de expedición:", title.year&.name || "Sin especificar"]
          ]
          pdf.text "Cédula profesional", style: :bold, size: 10, color: "EF4E50"
          pdf.table(cedula_rows, cell_style: { size: 10, padding: [3, 6, 3, 6] }, column_widths: [170, 330]) do
            row(0..-1).columns(0).font_style = :bold
          end
          pdf.move_down 4
        end
      end

      relaciones = MemberRelationship
                   .includes(
                     member_a: [:role, :organization, :criminal_link],
                     member_b: [:role, :organization, :criminal_link]
                   )
                   .where("member_a_id = :id OR member_b_id = :id", id: member.id)
                   .where(<<~SQL)
                     EXISTS (
                       SELECT 1
                       FROM hits_members hm
                       WHERE hm.member_id = member_relationships.member_a_id
                     )
                     AND EXISTS (
                       SELECT 1
                       FROM hits_members hm
                       WHERE hm.member_id = member_relationships.member_b_id
                     )
                   SQL

      if member.involved == false
        rol_text = +""
        rol_text << (cr || "Sin definir")

        if cr == "Servicios lícitos"
          role_name = member.role&.name.to_s.strip
          extra_parts = []
          extra_parts << role_name if role_name.present? && role_name != "Servicios lícitos"

          if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
            org_name = member.organization&.name.to_s.strip
            extra_parts << org_name if org_name.present?
          end

          rol_text << "\n#{extra_parts.join(', ')}" if extra_parts.any?
        end

        if cr == "Autoridad expuesta" && member.appointments.empty? && member.role&.name.to_s.strip == "Regidor"
          rol_text << "\nRegidor/funcionario municipal"

          if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
            muni = member.organization&.county&.name.to_s.strip
            st   = member.organization&.county&.state&.shortname.to_s.strip
            rol_text << " en #{muni}, #{st}" if muni.present? && st.present?
          end
        end

        if cr == "Autoridad expuesta" && member.appointments.empty?
          role_name = member.role&.name.to_s.strip

          if role_name.present? && role_name != "Regidor" && role_name != cr
            line2_parts = [role_name]

            if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
              org_name = member.organization&.name.to_s.strip
              line2_parts << org_name if org_name.present?
            end

            rol_text << "\n#{line2_parts.join(', ')}"
          end
        end

        pdf.table([["Rol o vínculo con el crimen organizado:", rol_text.strip]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) do
          row(0).columns(0).font_style = :bold
        end

        if relaciones.any?
          vinculos = relaciones.map do |rel|
            if rel.member_a_id == member.id
              otro = rel.member_b
              rel_label = rel.role_a_gender
            else
              otro = rel.member_a
              rel_label = rel.role_b_gender
            end

            otro_group = otro.criminal_role.to_s.strip.presence
            otro_org_name =
              if otro.criminal_link.present?
                otro.criminal_link.name.to_s.strip
              else
                otro.organization&.name.to_s.strip
              end

            otro_org_name = "organización por definir" if otro_org_name == "Por definir"

            parts = []
            parts << otro_group if otro_group.present?
            parts << otro_org_name if otro_org_name.present?

            "-#{rel_label} de #{[otro.firstname, otro.lastname1, otro.lastname2].map(&:to_s).map(&:strip).reject(&:empty?).join(' ')}, " \
            "#{parts.join(', ')}"
          end.join("\n")
        else
          org_name = cartel&.name || "Sin definir"
          pdf.table([["Organización:", org_name]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

          cartel_designado = nil
          cartel_fuente = nil
          cartel_fuente_tipo = nil

          if cartel&.designation
            cartel_designado = cartel
          elsif (ancestro_designado = designated_ancestor_for(cartel)).present?
            cartel_designado = ancestro_designado
            cartel_fuente = cartel_designado.name
            cartel_fuente_tipo = "subordinada a"
          elsif cartel&.allies.present?
            aliadas_designadas = Organization.where(id: cartel.allies).select(&:designation)
            if aliadas_designadas.any?
              cartel_designado = aliadas_designadas.first
              cartel_fuente = cartel_designado.name
              cartel_fuente_tipo = "aliada a"
            end
          end

          designacion_text =
            if cartel_designado.present? && cartel_fuente.nil?
              "Cártel designado como terrorista.\n" \
              "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            elsif cartel_designado.present? && cartel_fuente_tipo.present?
              "Organización #{cartel_fuente_tipo} #{cartel_fuente}\n" \
              "Cártel designado como terrorista.\n" \
              "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            else
              "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
            end

          pdf.table([["Designación del Departamento de Estado:", designacion_text]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
        end
      else
        org_name = cartel&.name || "Sin definir"
        pdf.table([["Organización:", org_name]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

        cartel_designado = nil
        cartel_fuente = nil
        cartel_fuente_tipo = nil

        if cartel&.designation
          cartel_designado = cartel
        elsif (ancestro_designado = designated_ancestor_for(cartel)).present?
          cartel_designado = ancestro_designado
          cartel_fuente = cartel_designado.name
          cartel_fuente_tipo = "subordinada a"
        elsif cartel&.allies.present?
          aliadas_designadas = Organization.where(id: cartel.allies).select(&:designation)
          if aliadas_designadas.any?
            cartel_designado = aliadas_designadas.first
            cartel_fuente = cartel_designado.name
            cartel_fuente_tipo = "aliada a"
          end
        end

        designacion_text =
          if cartel_designado.present? && cartel_fuente.nil?
            "Cártel designado como terrorista.\n" \
            "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
          elsif cartel_designado.present? && cartel_fuente_tipo.present?
            "Organización #{cartel_fuente_tipo} #{cartel_fuente}\n" \
            "Cártel designado como terrorista.\n" \
            "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
          else
            "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
          end

        pdf.table([["Designación del Departamento de Estado:", designacion_text]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

        rol_org_text = +""
        rol_org_text << (cr || "Sin definir")

        if cr == "Autoridad vinculada" && member.appointments.empty? && member.role&.name.to_s.strip == "Regidor"
          rol_org_text << "\nRegidor/funcionario municipal"

          if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
            muni = member.organization&.county&.name.to_s.strip
            st   = member.organization&.county&.state&.shortname.to_s.strip
            rol_org_text << " en #{muni}, #{st}" if muni.present? && st.present?
          end
        end

        if cr == "Autoridad vinculada" && member.appointments.empty?
          role_name = member.role&.name.to_s.strip

          if role_name.present? && role_name != "Regidor" && !["Autoridad vinculada", "Autoridad cooptada"].include?(role_name)
            line2_parts = [role_name]

            if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
              org_name = member.organization&.name.to_s.strip
              line2_parts << org_name if org_name.present?
            end

            rol_org_text << "\n#{line2_parts.join(', ')}"
          end
        end

        if cr == "Socio" && member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
          org_name = member.organization&.name.to_s.strip
          rol_org_text << "\n#{org_name}" if org_name.present?
        end

        pdf.table([["Rol o vínculo con la organización:", rol_org_text]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
      end

      if member.involved == false && relaciones.any?
        vinculos = relaciones.map do |rel|
          if rel.member_a_id == member.id
            otro = rel.member_b
            rel_label = rel.role_a_gender
          else
            otro = rel.member_a
            rel_label = rel.role_b_gender
          end

          otro_group = otro.criminal_role.to_s.strip.presence

          otro_org_name =
            if otro.criminal_link.present?
              otro.criminal_link.name.to_s.strip
            else
              otro.organization&.name.to_s.strip
            end

          otro_org_name = "organización por definir" if otro_org_name == "Por definir"

          parts = []
          parts << otro_group if otro_group.present?
          parts << otro_org_name if otro_org_name.present?

          "-#{rel_label} de #{[otro.firstname, otro.lastname1, otro.lastname2].map(&:to_s).map(&:strip).reject(&:empty?).join(' ')}, " \
          "#{parts.join(', ')}"
        end.join("\n")

        pdf.table([["Probables vínculos de #{member.firstname}:", vinculos]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) do
          row(0).columns(0).font_style = :bold
        end

        relacion_orgs = relaciones.map do |rel|
          otro = rel.member_a_id == member.id ? rel.member_b : rel.member_a

          if otro.criminal_link.present?
            otro.criminal_link.name.to_s.strip
          else
            otro.organization&.name.to_s.strip
          end
        end.reject(&:blank?).uniq

        relacion_unica_nombre = relacion_orgs.size == 1 ? relacion_orgs.first : nil
        relacion_unica_nombre = nil if relacion_unica_nombre == "Por definir"

        relacion_cartel = nil
        relacion_cartel_designado = nil
        relacion_fuente = nil
        relacion_fuente_tipo = nil

        if relacion_unica_nombre.present?
          relacion_cartel = Organization.find_by(name: relacion_unica_nombre)

          if relacion_cartel&.designation
            relacion_cartel_designado = relacion_cartel
          elsif (ancestro_designado = designated_ancestor_for(relacion_cartel)).present?
            relacion_cartel_designado = ancestro_designado
            relacion_fuente = relacion_cartel_designado.name
            relacion_fuente_tipo = "subordinada a"
          elsif relacion_cartel&.allies.present?
            aliadas_designadas = Organization.where(id: relacion_cartel.allies).select(&:designation)
            if aliadas_designadas.any?
              relacion_cartel_designado = aliadas_designadas.first
              relacion_fuente = relacion_cartel_designado.name
              relacion_fuente_tipo = "aliada a"
            end
          end
        end

        if relacion_unica_nombre.present?
          designacion_texto =
            if relacion_cartel_designado.present? && relacion_fuente.nil?
              "Cártel designado como terrorista.\n#{relacion_cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            elsif relacion_cartel_designado.present? && relacion_fuente_tipo.present?
              "Organización #{relacion_fuente_tipo} #{relacion_fuente}\n" \
              "Cártel designado como terrorista.\n" \
              "#{relacion_cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            else
              "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
            end

          pdf.table([["Designación del Departamento de Estado:", designacion_texto]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) do
            row(0).columns(0).font_style = :bold
          end
        end
      end

      if member.notes.any?
        notes_text = member.notes.map(&:story).join("\n\n")
        pdf.table([["", notes_text]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330])
      end

      appts = member.appointments.to_a
      appts_dedup = h.respond_to?(:dedup_appointments_for_view) ? h.dedup_appointments_for_view(appts) : []
      if appts_dedup.any?
        lista = appts_dedup
                  .sort_by { |(_a, s, e)| [s || Date.new(1,1,1), e || Date.new(9999,12,31)] }
                  .map do |appt, s, e|
                    linea = +"#{appt.role&.name || 'Cargo'}"
                    linea << ", #{appt.organization.name}" if appt.organization.present?
                    if s.present? || e.present?
                      span = h.respond_to?(:appt_span_label) ? h.appt_span_label(s, e) : [s, e].compact.map { |d| d.strftime("%d/%m/%Y") }.join(" - ")
                      linea << "\n#{span}"
                    end
                    linea
                  end
                  .join("\n")
        pdf.table([["Nombramientos / Cargos:", lista]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
      end

      show_related_hits = (member.involved == false && relaciones.any?)

      base_hits = member.hits.order(date: :desc).to_a

      related_hits =
        if show_related_hits
          seen_links = base_hits.map(&:link).compact

          others = relaciones.map { |rel| rel.member_a_id == member.id ? rel.member_b : rel.member_a }.compact.uniq
          rel_hits = others.flat_map { |m| m.hits.to_a }

          rel_hits = rel_hits.select { |h| h.link.present? && !seen_links.include?(h.link) }

          rel_hits
            .uniq { |h| h.link }
            .sort_by { |h| h.date || Date.new(1,1,1) }
            .reverse
        else
          []
        end

      fmt_hit = lambda do |hit|
        parts = ["#{hit.date.strftime('%d/%m/%y')} —"]
        parts << "#{hit.town.county.name}," unless hit.town.county.name == "Sin definir"
        parts << hit.town.county.state.shortname
        line = "• " + parts.join(" ")
        line += "\n  #{hit.link}" if hit.link.present?
        line
      end

      hits_lines = base_hits.map { |h| fmt_hit.call(h) }
      if related_hits.any?
        hits_lines << "—"
        hits_lines.concat(related_hits.map { |h| fmt_hit.call(h) })
      end

      if hits_lines.any?
        pdf.table([["Actividad/menciones:", hits_lines.join("\n")]],
                  cell_style: { size: 10, padding: [4, 6, 4, 6] },
                  column_widths: [170, 330]) do
          row(0).columns(0).font_style = :bold
        end
      end

      pdf.move_down 16
    end

    send_data pdf.render, filename: "#{clave}.pdf", type: "application/pdf", disposition: "attachment"
  end


  def download_bulk_results_pdf
    @bulk_query_run = BulkQueryRun.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless @bulk_query_run

    @user = @bulk_query_run.user
    invalid_rows = @bulk_query_run.invalid_rows_data || []
    valid_rows = @bulk_query_run.valid_rows_data || []
    summary = @bulk_query_run.summary_stats || {}

    # Obtener todas las queries con matches
    all_queries = @bulk_query_run.queries.to_a
    all_matches = []

    all_queries.each do |query|
      if query.outcome.is_a?(Array) && query.outcome.any?
        reference = valid_rows.find { |r| r["query_id"] == query.id }&.[]("reference") || "N/A"
        members = Member.where(id: query.outcome).includes(:fake_identities, :titles, :notes, appointments: [:organization, :role])
        members.each do |member|
          all_matches << { member: member, reference: reference }
        end
      end
    end

    h = ApplicationController.helpers

    # Configurar PDF
    pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
    pdf.font_families.update("Poppins" => {
      normal: Rails.root.join("app/assets/fonts/Poppins-Regular.ttf"),
      bold:   Rails.root.join("app/assets/fonts/Poppins-Bold.ttf")
    })
    pdf.font "Poppins"

    pdf.text "CONSULTA MASIVA - RESULTADOS", size: 16, style: :bold, align: :center, color: "33333C"
    pdf.move_down 20

    # SECCIÓN 1: RESUMEN
    pdf.text "Resumen de Consulta Múltiple", size: 12, style: :bold, color: "EF4E50"
    pdf.move_down 8

    summary_data = [
      ["Total de filas en CSV:", (summary["total_csv_rows"] || 0).to_s],
      ["Consultas efectivas realizadas:", (summary["effective_queries"] || 0).to_s],
      ["Consultas con coincidencias:", (summary["queries_with_matches"] || 0).to_s],
      ["Consultas sin coincidencias:", (summary["queries_without_matches"] || 0).to_s],
      ["Fecha/hora de carga:", summary["uploaded_at"] ? Time.parse(summary["uploaded_at"]).in_time_zone("America/Mexico_City").strftime("%d/%m/%Y %H:%M") : "No disponible"],
      ["Última actualización BD:", summary["dataset_last_updated_at"] ? Time.parse(summary["dataset_last_updated_at"]).in_time_zone("America/Mexico_City").strftime("%d/%m/%Y %H:%M") : "No disponible"],
      ["Total de registros en BD:", (summary["total_members_in_db"] || 0).to_s]
    ]
    summary_data << ["Filas inválidas (no procesadas):", (summary["invalid_rows_count"] || 0).to_s] if summary["invalid_rows_count"].to_i > 0

    pdf.table(summary_data, cell_style: { size: 10, padding: [4, 6, 4, 6] }, column_widths: [200, 300]) do
      row(0..-1).columns(0).font_style = :bold
    end

    pdf.move_down 20

    # SECCIÓN 2: TABLA INVÁLIDAS
    if invalid_rows.any?
      pdf.text "CONSULTAS INVÁLIDAS", size: 12, style: :bold, color: "EF4E50"
      pdf.move_down 8

      first_invalid = invalid_rows[0]
      is_segmented = first_invalid["firstname"].present? || first_invalid["lastname1"].present? || first_invalid["lastname2"].present?

      headers = if is_segmented
        ["Referencia", "Nombre propio", "Apellido paterno", "Apellido materno", "Criterio"]
      else
        ["Referencia", "Nombre completo", "Criterio"]
      end

      table_data = [headers]
      invalid_rows.first(200).each do |row|
        if is_segmented
          table_data << [row["reference"].to_s, row["firstname"].to_s, row["lastname1"].to_s, row["lastname2"].to_s, row["reason"].to_s]
        else
          table_data << [row["reference"].to_s, row["name"].to_s, row["reason"].to_s]
        end
      end

      col_widths = if is_segmented
        [80, 90, 90, 90, 100]
      else
        [100, 150, 150]
      end

      pdf.table(table_data, cell_style: { size: 9, padding: [3, 5, 3, 5] }, column_widths: col_widths, header: true) do
        row(0).font_style = :bold
        row(0).background_color = "33333C"
        row(0).text_color = "FFFFFF"
      end

      if invalid_rows.size > 200
        pdf.text "Mostrando 200 de #{invalid_rows.size} consultas inválidas", size: 9, style: :italic, color: "888888"
      end
      pdf.move_down 20
    end

    # SECCIÓN 3: TABLA VÁLIDAS
    if valid_rows.any?
      pdf.text "CONSULTAS VÁLIDAS", size: 12, style: :bold, color: "EF4E50"
      pdf.move_down 8

      first_valid = valid_rows[0]
      is_segmented = first_valid["firstname"].present? || first_valid["lastname1"].present? || first_valid["lastname2"].present?

      headers = if is_segmented
        ["Referencia", "Nombre propio", "Apellido paterno", "Apellido materno", "Probables homónimos", "Coincidencias"]
      else
        ["Referencia", "Nombre completo", "Probables homónimos", "Coincidencias"]
      end

      table_data = [headers]
      valid_rows.first(200).each do |row|
        homo_score = row["homo_score"].to_i
        homonyms_text = case homo_score
          when 0...1 then "Nombre único"
          when 1...2 then "Sólo 1"
          when 2...3 then "Más de 2"
          when 3...4 then "Más de 3"
          when 4...5 then "Más de 4"
          when 5...6 then "Más de 5"
          when 6...7 then "Más de 6"
          when 7...8 then "Más de 7"
          when 8...9 then "Más de 8"
          when 9...10 then "Más de 9"
          when 10...20 then "Más de 10"
          when 20...30 then "Más de 20"
          when 30...40 then "Más de 30"
          when 40...50 then "Más de 40"
          when 50...60 then "Más de 50"
          when 60...70 then "Más de 60"
          when 70...80 then "Más de 70"
          when 80...90 then "Más de 80"
          when 90...100 then "Más de 90"
          when 100...200 then "Más de 100"
          when 200...500 then "Más de 200"
          when 500...1000 then "Más de 500"
          else "Más de 1000"
        end

        if is_segmented
          table_data << [row["reference"].to_s, row["firstname"].to_s, row["lastname1"].to_s, row["lastname2"].to_s, homonyms_text, (row["result_count"] || 0).to_s]
        else
          table_data << [row["reference"].to_s, row["name"].to_s, homonyms_text, (row["result_count"] || 0).to_s]
        end
      end

      col_widths = if is_segmented
        [70, 75, 75, 75, 85, 50]
      else
        [90, 130, 90, 60]
      end

      pdf.table(table_data, cell_style: { size: 9, padding: [3, 5, 3, 5] }, column_widths: col_widths, header: true) do
        row(0).font_style = :bold
        row(0).background_color = "33333C"
        row(0).text_color = "FFFFFF"
      end

      if valid_rows.size > 200
        pdf.text "Mostrando 200 de #{valid_rows.size} consultas válidas", size: 9, style: :italic, color: "888888"
      end

      # Leyenda explicativa (ABAJO de la tabla)
      pdf.move_down 8
      pdf.text "• Coincidencias: Número de registros de personas señaladas o personas expuestas que coinciden con los parámetros de consulta.", size: 9, color: "666666"
      pdf.move_down 4
      pdf.text "• Probables homónimos: Estimación del número de mexicanos adultos con el nombre y apellidos consultados o alguna de sus variantes.", size: 9, color: "666666"
      pdf.move_down 20
    end

    # SECCIÓN 4: COINCIDENCIAS (fichas completas - código LITERAL de bulk_query_pdf adaptado)
    if all_matches.any?
      pdf.text "COINCIDENCIAS", size: 12, style: :bold, color: "EF4E50"
      pdf.move_down 12

      all_matches.each_with_index do |match_data, idx|
        member = match_data[:member]
        reference = match_data[:reference]
        counter = "#{idx + 1} de #{all_matches.size}"
        cartel = member.criminal_link.present? ? member.criminal_link : member.organization
        memberGroup = nil
        cr = member.criminal_role.to_s.strip.presence

        # Header
        pdf.fill_color "FFFFFF"
        pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 18
        pdf.fill_color "33333C"
        pdf.text "#{counter} — Referencia interna: #{reference}", align: :center, style: :bold
        pdf.move_down 6

        data = []
        data << ["Nombre(s):", member.firstname]
        data << ["Apellido paterno:", member.lastname1]
        data << ["Apellido materno:", member.lastname2]

        if member.alias.present? && member.alias.any?
          data << ["Alias:", member.alias.join(", ")]
        end

        if member.birthday?
          fecha_nac = if member.birthday_aprox?
                        "circa #{member.birthday.strftime('%Y')}"
                      else
                        member.birthday.strftime("%d/%m/%Y")
                      end
          data << ["Fecha de nacimiento:", fecha_nac]
        end

        if member.fake_identities.any?
          lista = member.fake_identities.map { |ide| "-#{ide.firstname} #{ide.lastname1} #{ide.lastname2}" }.join("\n")
          data << ["Identidades falsas/alternativas:", lista]
        end

        clasificacion = member.involved == false ? "Persona expuesta" : "Persona señalada"
        data << ["Clasificación:", clasificacion]

        pdf.table(data, cell_style: { size: 10, padding: [4, 6, 4, 6] }, column_widths: [170, 330]) do
          row(0..-1).columns(0).font_style = :bold
        end

        if member.ofac_designation? || member.ofac_ent_num.present?
          ofac_text = if member.ofac_designation?
                        "Persona incluida en listado OFAC."
                      else
                        "Registro relacionado con OFAC."
                      end

          if member.ofac_ent_num.present?
            ofac_text << "\nFolio OFAC: #{member.ofac_ent_num}"
          end

          pdf.table([["Designación OFAC:", ofac_text]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) do
            row(0).columns(0).font_style = :bold
          end
        end

        if member.titles.any?
          pdf.move_down 6
          member.titles.each do |title|
            cedula_rows = [
              ["Número:", title.legacy_id],
              ["Tipo:", title.type],
              ["Profesión:", title.profesion.to_s.titleize],
              ["Institución:", title.organization&.name],
              ["Año de expedición:", title.year&.name || "Sin especificar"]
            ]
            pdf.text "Cédula profesional", style: :bold, size: 10, color: "EF4E50"
            pdf.table(cedula_rows, cell_style: { size: 10, padding: [3, 6, 3, 6] }, column_widths: [170, 330]) do
              row(0..-1).columns(0).font_style = :bold
            end
            pdf.move_down 4
          end
        end

        relaciones = MemberRelationship
                     .includes(
                       member_a: [:role, :organization, :criminal_link],
                       member_b: [:role, :organization, :criminal_link]
                     )
                     .where("member_a_id = :id OR member_b_id = :id", id: member.id)
                     .where(<<~SQL)
                       EXISTS (
                         SELECT 1
                         FROM hits_members hm
                         WHERE hm.member_id = member_relationships.member_a_id
                       )
                       AND EXISTS (
                         SELECT 1
                         FROM hits_members hm
                         WHERE hm.member_id = member_relationships.member_b_id
                       )
                     SQL

        if member.involved == false
          rol_text = +""
          rol_text << (cr || "Sin definir")

          if cr == "Servicios lícitos"
            role_name = member.role&.name.to_s.strip
            extra_parts = []
            extra_parts << role_name if role_name.present? && role_name != "Servicios lícitos"

            if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
              org_name = member.organization&.name.to_s.strip
              extra_parts << org_name if org_name.present?
            end

            rol_text << "\n#{extra_parts.join(', ')}" if extra_parts.any?
          end

          if cr == "Autoridad expuesta" && member.appointments.empty? && member.role&.name.to_s.strip == "Regidor"
            rol_text << "\nRegidor/funcionario municipal"

            if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
              muni = member.organization&.county&.name.to_s.strip
              st   = member.organization&.county&.state&.shortname.to_s.strip
              rol_text << " en #{muni}, #{st}" if muni.present? && st.present?
            end
          end

          if cr == "Autoridad expuesta" && member.appointments.empty?
            role_name = member.role&.name.to_s.strip

            if role_name.present? && role_name != "Regidor" && role_name != cr
              line2_parts = [role_name]

              if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
                org_name = member.organization&.name.to_s.strip
                line2_parts << org_name if org_name.present?
              end

              rol_text << "\n#{line2_parts.join(', ')}"
            end
          end

          pdf.table([["Rol o vínculo con el crimen organizado:", rol_text.strip]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) do
            row(0).columns(0).font_style = :bold
          end

          if relaciones.any?
            vinculos = relaciones.map do |rel|
              if rel.member_a_id == member.id
                otro = rel.member_b
                rel_label = rel.role_a_gender
              else
                otro = rel.member_a
                rel_label = rel.role_b_gender
              end

              otro_group = otro.criminal_role.to_s.strip.presence
              otro_org_name =
                if otro.criminal_link.present?
                  otro.criminal_link.name.to_s.strip
                else
                  otro.organization&.name.to_s.strip
                end

              otro_org_name = "organización por definir" if otro_org_name == "Por definir"

              parts = []
              parts << otro_group if otro_group.present?
              parts << otro_org_name if otro_org_name.present?

              "-#{rel_label} de #{[otro.firstname, otro.lastname1, otro.lastname2].map(&:to_s).map(&:strip).reject(&:empty?).join(' ')}, " \
              "#{parts.join(', ')}"
            end.join("\n")
          else
            org_name = cartel&.name || "Sin definir"
            pdf.table([["Organización:", org_name]],
                      cell_style: { size: 10, padding: [4, 6, 4, 6] },
                      column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

            cartel_designado = nil
            cartel_fuente = nil
            cartel_fuente_tipo = nil

            if cartel&.designation
              cartel_designado = cartel
            elsif cartel&.allies.present?
              aliadas_designadas = Organization.where(id: cartel.allies).select(&:designation)
              if aliadas_designadas.any?
                cartel_designado = aliadas_designadas.first
                cartel_fuente = cartel_designado.name
                cartel_fuente_tipo = "aliada a"
              end
            end

            designacion_text =
              if cartel_designado.present? && cartel_fuente.nil?
                "Cártel designado como terrorista.\n" \
                "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
              elsif cartel_designado.present? && cartel_fuente_tipo.present?
                "Organización #{cartel_fuente_tipo} #{cartel_fuente}\n" \
                "Cártel designado como terrorista.\n" \
                "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
              else
                "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
              end

            pdf.table([["Designación del Departamento de Estado:", designacion_text]],
                      cell_style: { size: 10, padding: [4, 6, 4, 6] },
                      column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
          end
        else
          org_name = cartel&.name || "Sin definir"
          pdf.table([["Organización:", org_name]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

          cartel_designado = nil
          cartel_fuente = nil
          cartel_fuente_tipo = nil

          if cartel&.designation
            cartel_designado = cartel
          elsif cartel&.allies.present?
            aliadas_designadas = Organization.where(id: cartel.allies).select(&:designation)
            if aliadas_designadas.any?
              cartel_designado = aliadas_designadas.first
              cartel_fuente = cartel_designado.name
              cartel_fuente_tipo = "aliada a"
            end
          end

          designacion_text =
            if cartel_designado.present? && cartel_fuente.nil?
              "Cártel designado como terrorista.\n" \
              "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            elsif cartel_designado.present? && cartel_fuente_tipo.present?
              "Organización #{cartel_fuente_tipo} #{cartel_fuente}\n" \
              "Cártel designado como terrorista.\n" \
              "#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
            else
              "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
            end

          pdf.table([["Designación del Departamento de Estado:", designacion_text]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }

          rol_org_text = +""
          rol_org_text << (cr || "Sin definir")

          if cr == "Autoridad vinculada" && member.appointments.empty? && member.role&.name.to_s.strip == "Regidor"
            rol_org_text << "\nRegidor/funcionario municipal"

            if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
              muni = member.organization&.county&.name.to_s.strip
              st   = member.organization&.county&.state&.shortname.to_s.strip
              rol_org_text << " en #{muni}, #{st}" if muni.present? && st.present?
            end
          end

          if cr == "Autoridad vinculada" && member.appointments.empty?
            role_name = member.role&.name.to_s.strip

            if role_name.present? && role_name != "Regidor" && !["Autoridad vinculada", "Autoridad cooptada"].include?(role_name)
              line2_parts = [role_name]

              if member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
                org_name = member.organization&.name.to_s.strip
                line2_parts << org_name if org_name.present?
              end

              rol_org_text << "\n#{line2_parts.join(', ')}"
            end
          end

          if cr == "Socio" && member.organization_id.present? && member.criminal_link_id.present? && member.organization_id != member.criminal_link_id
            org_name = member.organization&.name.to_s.strip
            rol_org_text << "\n#{org_name}" if org_name.present?
          end

          pdf.table([["Rol o vínculo con la organización:", rol_org_text]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
        end

        if member.involved == false && relaciones.any?
          vinculos = relaciones.map do |rel|
            if rel.member_a_id == member.id
              otro = rel.member_b
              rel_label = rel.role_a_gender
            else
              otro = rel.member_a
              rel_label = rel.role_b_gender
            end

            otro_group = otro.criminal_role.to_s.strip.presence

            otro_org_name =
              if otro.criminal_link.present?
                otro.criminal_link.name.to_s.strip
              else
                otro.organization&.name.to_s.strip
              end

            otro_org_name = "organización por definir" if otro_org_name == "Por definir"

            parts = []
            parts << otro_group if otro_group.present?
            parts << otro_org_name if otro_org_name.present?

            "-#{rel_label} de #{[otro.firstname, otro.lastname1, otro.lastname2].map(&:to_s).map(&:strip).reject(&:empty?).join(' ')}, " \
            "#{parts.join(', ')}"
          end.join("\n")

          pdf.table([["Probables vínculos de #{member.firstname}:", vinculos]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) do
            row(0).columns(0).font_style = :bold
          end

          relacion_orgs = relaciones.map do |rel|
            otro = rel.member_a_id == member.id ? rel.member_b : rel.member_a

            if otro.criminal_link.present?
              otro.criminal_link.name.to_s.strip
            else
              otro.organization&.name.to_s.strip
            end
          end.reject(&:blank?).uniq

          relacion_unica_nombre = relacion_orgs.size == 1 ? relacion_orgs.first : nil
          relacion_unica_nombre = nil if relacion_unica_nombre == "Por definir"

          relacion_cartel = nil
          relacion_cartel_designado = nil
          relacion_fuente = nil
          relacion_fuente_tipo = nil

          if relacion_unica_nombre.present?
            relacion_cartel = Organization.find_by(name: relacion_unica_nombre)

            if relacion_cartel&.designation
              relacion_cartel_designado = relacion_cartel
            elsif relacion_cartel&.allies.present?
              aliadas_designadas = Organization.where(id: relacion_cartel.allies).select(&:designation)
              if aliadas_designadas.any?
                relacion_cartel_designado = aliadas_designadas.first
                relacion_fuente = relacion_cartel_designado.name
                relacion_fuente_tipo = "aliada a"
              end
            end
          end

          if relacion_unica_nombre.present?
            designacion_texto =
              if relacion_cartel_designado.present? && relacion_fuente.nil?
                "Cártel designado como terrorista.\n#{relacion_cartel_designado.designation_date.strftime('%d/%m/%Y')}"
              elsif relacion_cartel_designado.present? && relacion_fuente_tipo.present?
                "Organización #{relacion_fuente_tipo} #{relacion_fuente}\n" \
                "Cártel designado como terrorista.\n" \
                "#{relacion_cartel_designado.designation_date.strftime('%d/%m/%Y')}"
              else
                "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."
              end

            pdf.table([["Designación del Departamento de Estado:", designacion_texto]],
                      cell_style: { size: 10, padding: [4, 6, 4, 6] },
                      column_widths: [170, 330]) do
              row(0).columns(0).font_style = :bold
            end
          end
        end

        if member.notes.any?
          notes_text = member.notes.map(&:story).join("\n\n")
          pdf.table([["", notes_text]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330])
        end

        appts = member.appointments.to_a
        appts_dedup = h.respond_to?(:dedup_appointments_for_view) ? h.dedup_appointments_for_view(appts) : []
        if appts_dedup.any?
          lista = appts_dedup
                    .sort_by { |(_a, s, e)| [s || Date.new(1,1,1), e || Date.new(9999,12,31)] }
                    .map do |appt, s, e|
                      linea = +"#{appt.role&.name || 'Cargo'}"
                      linea << ", #{appt.organization.name}" if appt.organization.present?
                      if s.present? || e.present?
                        span = h.respond_to?(:appt_span_label) ? h.appt_span_label(s, e) : [s, e].compact.map { |d| d.strftime("%d/%m/%Y") }.join(" - ")
                        linea << "\n#{span}"
                      end
                      linea
                    end
                    .join("\n")
          pdf.table([["Nombramientos / Cargos:", lista]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) { row(0).columns(0).font_style = :bold }
        end

        show_related_hits = (member.involved == false && relaciones.any?)

        base_hits = member.hits.order(date: :desc).to_a

        related_hits =
          if show_related_hits
            seen_links = base_hits.map(&:link).compact

            others = relaciones.map { |rel| rel.member_a_id == member.id ? rel.member_b : rel.member_a }.compact.uniq
            rel_hits = others.flat_map { |m| m.hits.to_a }

            rel_hits = rel_hits.select { |h| h.link.present? && !seen_links.include?(h.link) }

            rel_hits
              .uniq { |h| h.link }
              .sort_by { |h| h.date || Date.new(1,1,1) }
              .reverse
          else
            []
          end

        fmt_hit = lambda do |hit|
          parts = ["#{hit.date.strftime('%d/%m/%y')} —"]
          parts << "#{hit.town.county.name}," unless hit.town.county.name == "Sin definir"
          parts << hit.town.county.state.shortname
          line = "• " + parts.join(" ")
          line += "\n  #{hit.link}" if hit.link.present?
          line
        end

        hits_lines = base_hits.map { |h| fmt_hit.call(h) }
        if related_hits.any?
          hits_lines << "—"
          hits_lines.concat(related_hits.map { |h| fmt_hit.call(h) })
        end

        if hits_lines.any?
          pdf.table([["Actividad/menciones:", hits_lines.join("\n")]],
                    cell_style: { size: 10, padding: [4, 6, 4, 6] },
                    column_widths: [170, 330]) do
            row(0).columns(0).font_style = :bold
          end
        end

        pdf.move_down 16
      end
    end

    clave = "#{@user.member.firstname.first}#{@user.member.lastname1.first}-#{@bulk_query_run.id}"
    send_data pdf.render, filename: "#{clave}-resultados.pdf", type: "application/pdf", disposition: "attachment"
  end

  private

  def authenticate_bulk_access
    return if session[:user_id].present?
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def normalize_headers(headers_raw)
    headers_raw.map do |h|
      normalized = case h.to_s.strip.downcase
      when "referencia", "reference" then "reference"
      when "nombre propio", "firstname" then "firstname"
      when "apellido paterno", "lastname1" then "lastname1"
      when "apellido materno", "lastname2" then "lastname2"
      when "nombre completo", "name" then "name"
      else h.to_s.strip.downcase
      end
      normalized.to_sym
    end
  end

  def validate_csv_headers(headers_normalized)
    required = [:reference]
    has_name_fields = headers_normalized.include?(:firstname) || headers_normalized.include?(:lastname1) || headers_normalized.include?(:lastname2)
    has_full_name = headers_normalized.include?(:name)

    unless has_name_fields || has_full_name
      return { valid: false, message: "El CSV debe tener: (nombre propio + apellido paterno + apellido materno) O (nombre completo)" }
    end

    # Verificar duplicados
    if headers_normalized.uniq.length != headers_normalized.length
      return { valid: false, message: "El CSV tiene columnas duplicadas" }
    end

    { valid: true }
  end

  def match?(input, target)
    return false if input.blank? || target.blank?
    input == target
  end

  def normalize(s)
    I18n.transliterate(s.to_s.strip.downcase)
  end

  def compute_homo_score(firstname, lastname1, lastname2)
    names_norm = Name.all.pluck(:word, :freq).to_h do |w, f|
      [normalize(w), f.to_i]
    end
    keys = names_norm.keys

    pick_best = lambda do |norm|
      if keys.include?(norm)
        norm
      else
        contained = keys.select { |k| norm.include?(k) }
        if contained.any?
          contained.max_by(&:length)
        else
          containing = keys.select { |k| k.include?(norm) }
          containing.max_by(&:length)
        end
      end
    end

    freqs = [firstname, lastname1, lastname2].map do |val|
      norm = normalize(val)
      parts = norm.split(/\s+/).reject(&:blank?)

      if parts.length > 1
        part_freqs = parts.map do |p|
          pbest = pick_best.call(p)
          pbest ? names_norm[pbest] : 5
        end

        maxf = part_freqs.max || 5
        avgf = (part_freqs.sum.to_f / part_freqs.length)

        bonus = [0.10 * (parts.length - 1), 0.30].min
        ( [avgf, maxf].max * (1.0 + bonus) ).round
      else
        best = pick_best.call(norm)
        best ? names_norm[best] : 5
      end

    end

    ((freqs[0] * freqs[1] * freqs[2]) / 10000.0).round
  end

  def compute_name_score(full_name)
    names_norm = Name.all.pluck(:word, :freq).to_h { |w, f| [normalize(w), f.to_i] }
    keys = names_norm.keys

    tokens = normalize(full_name).split(/\s+/).reject(&:blank?)
    return nil if tokens.empty?

    freqs = tokens.map { |t| token_freq_strict(names_norm, keys, t) }.sort.reverse

    top3 = freqs.first(3)
    top3 << 5 while top3.length < 3

    base = ((top3[0] * top3[1] * top3[2]) / 10000.0).round

    extras = [tokens.length - 3, 0].max
    penalty = (0.60 ** extras)

    (base * penalty).round
  end

  def token_freq_strict(names_norm, keys, token_norm)
    return 5 if token_norm.blank?

    return names_norm[token_norm] if names_norm.key?(token_norm)

    contained = keys.select { |k| token_norm.include?(k) }
    best = if contained.any?
      contained.max_by(&:length)
    else
      containing = keys.select { |k| k.include?(token_norm) }
      containing.max_by(&:length)
    end

    base = best ? names_norm[best] : 5
    (base * 0.25).round
  end

end
