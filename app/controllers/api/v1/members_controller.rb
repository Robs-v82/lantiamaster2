require "role_classifier"
module Api
  module V1
    class MembersController < BaseController
      include RoleClassifier
      include MonthlyQueryLimits

      def search
        qp = search_params

        # ✅ Rate limit por organización (mensual)
        suscription = set_suscription(current_api_user)
        info = consultas_mensuales(current_api_user)
        remaining = [suscription[:points] - info[:total_org], 0].max

        if info[:total_org] >= suscription[:points]
          return render json: {
            request_id: request.request_id,
            status: 429,
            errors: [
              {
                code: "rate_limit_exceeded",
                message: "Has rebasado el límite mensual de tu plan. Escribe a contacto@lantiaintelligence.com para contratar consultas adicionales."
              }
            ],
            meta: {
              plan: suscription[:level],
              limit: suscription[:points],
              used: info[:total_org],
              remaining: remaining
            }
          }, status: :too_many_requests
        end

        # --- 1) Validación: dos modos ---
        if qp[:name].present?
          invalid = qp[:name].to_s.strip.length < 4
          if invalid
            return render json: {
              request_id: request.request_id,
              status: 422,
              errors: [
                {
                  code: "invalid_request",
                  message: "Debes completar name (>=4 chars)."
                }
              ]
            }, status: :unprocessable_entity
          end
        else
          required = %i[firstname lastname1 lastname2]
          invalid = required.any? { |k| qp[k].blank? || qp[k].to_s.strip.length < 2 }
          if invalid
            return render json: {
              request_id: request.request_id,
              status: 422,
              errors: [
                {
                  code: "invalid_request",
                  message: "Debes completar firstname, lastname1, lastname2 (>=2 chars)."
                }
              ]
            }, status: :unprocessable_entity
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
        input_name = qp[:name].present? ? I18n.transliterate(qp[:name].to_s.strip.downcase) : nil
        input_firstname = qp[:name].present? ? nil : I18n.transliterate(qp[:firstname].to_s.strip.downcase)
        input_lastname1 = qp[:name].present? ? nil : I18n.transliterate(qp[:lastname1].to_s.strip.downcase)
        input_lastname2 = qp[:name].present? ? nil : I18n.transliterate(qp[:lastname2].to_s.strip.downcase)

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
            member_full = I18n.transliterate(member.fullname.to_s.downcase)
            real_match = match?(input_name, member_full)

            fake_match = member.fake_identities.any? do |fi|
              next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?
              fi_full = I18n.transliterate(fi.fullname.to_s.downcase)
              match?(input_name, fi_full)
            end

            real_match || fake_match
          else
            # --- Modo clásico (3 campos) ---
            real_match =
              match?(input_firstname, I18n.transliterate(member.firstname.to_s.downcase)) &&
              match?(input_lastname1, I18n.transliterate(member.lastname1.to_s.downcase)) &&
              match?(input_lastname2, I18n.transliterate(member.lastname2.to_s.downcase))

            fake_match = member.fake_identities.any? do |fi|
              next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?

              match?(input_firstname, I18n.transliterate(fi.firstname.to_s.downcase)) &&
              match?(input_lastname1, I18n.transliterate(fi.lastname1.to_s.downcase)) &&
              match?(input_lastname2, I18n.transliterate(fi.lastname2.to_s.downcase))
            end

            real_match || fake_match
          end
        end

        # --- Rate limit mensual (mismo concepto que UI) ---
        suscription = set_suscription(current_api_user) # {level, points}
        info = consultas_mensuales(current_api_user)    # {usuario, organizacion, total}

        if info[:total_org] >= suscription[:points]
          remaining = [suscription[:points] - info[:total_org], 0].max

          return render json: {
            request_id: request.request_id,
            status: 429,
            errors: [{
              code: "rate_limit_exceeded",
              message: "Has rebasado el límite mensual de tu plan. Escribe a contacto@lantiaintelligence.com para contratar consultas adicionales."
            }],
            meta: {
              plan: suscription[:level],
              limit: suscription[:points],
              used: info[:total_org],
              remaining: remaining
            }
          }, status: :too_many_requests
        end

        # --- 5) Guardado (default true) ---

        query_record = nil
        query_record = Query.create!(
          firstname: qp[:name].present? ? nil : qp[:firstname],
          lastname1: qp[:name].present? ? nil : qp[:lastname1],
          lastname2: qp[:name].present? ? nil : qp[:lastname2],
          homo_score: homo_score,
          outcome: potential_matches.map(&:id),
          search: Member.joins(:hits).distinct.count,
          user: current_api_user,
          member: current_api_user&.member,
          organization: current_api_user&.member&.organization
        )

        # --- 6) Payload members ---
        members_payload = potential_matches.map do |m|
          rolegroup = clasificar_rol(m)
          MemberOutcomeSerializer.new(m, rolegroup: rolegroup).as_json
        end

        # --- 7) Response ---
        render json: {
          request_id: request.request_id,
          status: 200,
          meta: {
            searched_at: Time.current.iso8601,
            plan: suscription[:level],
            limit: suscription[:points],
            used: info[:total_org],
            remaining: remaining
          },
          request: qp[:name].present? ? {
            name: qp[:name],
            homo_score: homo_score
          } : {
            firstname: qp[:firstname],
            lastname1: qp[:lastname1],
            lastname2: qp[:lastname2],
            homo_score: homo_score
          },
          query: {
            id: query_record&.id
          },
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
        names_data = Name.all.pluck(:word, :freq).map { |w, f| [w.to_s, f.to_i] }.to_h

        freqs = [firstname, lastname1, lastname2].map do |val|
          norm = normalize(val)
          matched_key = names_data.keys.find do |k|
            kn = normalize(k)
            norm.include?(kn) || kn.include?(norm)
          end
          matched_key ? names_data[matched_key] : 5
        end

        ((freqs[0] * freqs[1] * freqs[2]) / 10000.0).round
      end

    end
  end
end
