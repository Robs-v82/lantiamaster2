require "role_classifier"

module Api
  module V1
    class MembersController < BaseController
      include RoleClassifier
      include MonthlyQueryLimits

      def search
        qp = search_params

        # ✅ Rate limit por organización (mensual/anual según plan)
        suscription = set_suscription(current_api_user)
        ensure_trial_status!(current_api_user)
        info = consultas_en_periodo(current_api_user)
        remaining = [suscription[:points] - info[:total_org], 0].max

        if info[:total_org] >= suscription[:points]
          return render_api_error(
            status: :too_many_requests,
            code: "rate_limit_exceeded",
            message: "Has rebasado el límite mensual de tu plan. Escribe a contacto@lantiaintelligence.com para contratar consultas adicionales.",
            meta: {
              plan: suscription[:level],
              limit: suscription[:points],
              used: info[:total_org],
              remaining: remaining
            }
          )
        end

        # --- 1) Validación: dos modos ---
        if qp[:name].present?
          if qp[:name].to_s.strip.length < 4
            return render_api_error(
              status: :unprocessable_entity,
              code: "invalid_request",
              message: "Debes completar name (>=4 chars)."
            )
          end
        else
          required = %i[firstname lastname1 lastname2]
          invalid = required.any? { |k| qp[k].blank? || qp[k].to_s.strip.length < 2 }
          if invalid
            return render_api_error(
              status: :unprocessable_entity,
              code: "invalid_request",
              message: "Debes completar firstname, lastname1, lastname2 (>=2 chars)."
            )
          end
        end

        # --- 2) homo_score ---
        # Si viene name, solo lo usamos si lo mandan (no lo calculamos).
        homo_score =
          if qp[:name].present?
            qp[:homo_score].presence
          else
            qp[:homo_score].presence || compute_homo_score(qp[:firstname], qp[:lastname1], qp[:lastname2])
          end

        # --- 3) Normalización input ---
        input_name = qp[:name].present? ? normalize(qp[:name]) : nil
        input_firstname = qp[:name].present? ? nil : normalize(qp[:firstname])
        input_lastname1 = qp[:name].present? ? nil : normalize(qp[:lastname1])
        input_lastname2 = qp[:name].present? ? nil : normalize(qp[:lastname2])

        # --- 4) Matching ---
        potential_matches = Member.includes(
          :fake_identities,
          :notes,
          :organization,
          :criminal_link,
          hits: { town: { county: :state } },
          titles: [:organization, :year],
          appointments: [:organization, :role]
        ).distinct.select do |member|
          next false if member.hits.blank?

          # Omitir members sin al menos un nombre válido
          next false if member.firstname.blank? && member.lastname1.blank? && member.lastname2.blank? &&
                         member.fake_identities.none? { |fi| fi.firstname.present? || fi.lastname1.present? || fi.lastname2.present? }

          if input_name.present?
            # --- Modo NAME (string completo) ---
            member_full = normalize(member.fullname)
            real_match = match?(input_name, member_full)

            fake_match = member.fake_identities.any? do |fi|
              next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?
              fi_full = normalize(fi.fullname)
              match?(input_name, fi_full)
            end

            real_match || fake_match
          else
            # --- Modo clásico (3 campos) ---
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

            real_match || fake_match
          end
        end

        # --- 5) Guardado / auditoría ---
        dataset_last_updated_at = Member.maximum(:updated_at)
        query_record = Query.create!(
          firstname: qp[:firstname],
          lastname1: qp[:lastname1],
          lastname2: qp[:lastname2],
          homo_score: homo_score,
          outcome: potential_matches.map(&:id),
          search: Member.joins(:hits).distinct.count,
          user: current_api_user,
          member: current_api_user&.member,
          organization: current_api_user&.member&.organization,

          # audit
          source: "api",
          status_code: 200,
          success: true,
          request_id: request.request_id,
          result_count: potential_matches.size,
          dataset_last_updated_at: dataset_last_updated_at,
          query_label: qp[:name].presence || [qp[:firstname], qp[:lastname1], qp[:lastname2]].compact.join(" ")
        )

        # --- 6) Payload members ---
        members_payload = potential_matches.map do |m|
          rolegroup = clasificar_rol(m)
          MemberOutcomeSerializer.new(m, rolegroup: rolegroup).as_json
        end

        # --- 7) Response ---
        score = homo_score
        likelihood = namesake_likelihood(score)

        render json: {
          request_id: request.request_id,
          status: 200,
          meta: {
            api_version: api_version,
            searched_at: Time.current.in_time_zone("America/Mexico_City").iso8601,
            plan: suscription[:level],
            limit: suscription[:points],
            used: info[:total_org],
            remaining: remaining,
            last_updated_at: query_record.dataset_last_updated_at&.in_time_zone("America/Mexico_City")&.strftime("%Y-%m-%d %H:%M"),
          },
          request: qp[:name].present? ? {
            name: qp[:name],
            name_score: score,
            namesake_likelihood: likelihood
          } : {
            firstname: qp[:firstname],
            lastname1: qp[:lastname1],
            lastname2: qp[:lastname2],
            name_score: score,
            namesake_likelihood: likelihood
          },
          query: { id: query_record.id },
          results: {
            count: members_payload.length,
            members: members_payload
          }
        }, status: :ok
      end

      private

      def search_params
        params.permit(:name, :firstname, :lastname1, :lastname2, :homo_score)
      end

      def match?(input, candidate)
        return false if candidate.blank?
        return true if input.blank?
        input.include?(candidate) || candidate.include?(input)
      end

      def normalize(s)
        I18n.transliterate(s.to_s.strip.downcase)
      end

      # Replica la idea del JS: buscar frecuencia por “inclusion match” y default 5
      def compute_homo_score(firstname, lastname1, lastname2)
        # Index normalizado: "jose" => 175, etc. (acentos/capitalización ya no importan)
        names_norm = Name.all.pluck(:word, :freq).to_h do |w, f|
          [normalize(w), f.to_i]
        end
        keys = names_norm.keys

        # Helper local: exact > contained > containing
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

            # bono pequeño por compuesto (10%), capado a +30% aunque haya 3+ partes
            bonus = [0.10 * (parts.length - 1), 0.30].min
            ( [avgf, maxf].max * (1.0 + bonus) ).round
          else
            best = pick_best.call(norm)
            best ? names_norm[best] : 5
          end

        end

        ((freqs[0] * freqs[1] * freqs[2]) / 10000.0).round
      end

      def namesake_likelihood(score)
        s = score.to_i
        return nil if s <= 0

        if s < 2
          "low"
        elsif s < 5
          "medium"
        elsif s <= 10
          "high"
        else
          "very_high"
        end
      end

    end
  end
end
