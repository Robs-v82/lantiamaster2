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
  homo_score =
    if qp[:name].present?
      qp[:homo_score].presence || compute_name_score(qp[:name])
    else
      qp[:homo_score].presence || compute_homo_score(qp[:firstname], qp[:lastname1], qp[:lastname2])
    end

  # --- 3) Normalización input ---
  input_name = qp[:name].present? ? normalize(qp[:name]) : nil
  input_firstname = qp[:name].present? ? nil : normalize(qp[:firstname])
  input_lastname1 = qp[:name].present? ? nil : normalize(qp[:lastname1])
  input_lastname2 = qp[:name].present? ? nil : normalize(qp[:lastname2])

  # --- 4) Matching ---
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  base_scope = Member.joins(:hits).distinct
  Rails.logger.info("[#{request.request_id}] PERF A0 scope_built ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC)-t0)*1000).round}")

  # === Prefiltro SQL (barato) ===
  # Objetivo: reducir candidatos antes del matching Ruby.
  # Seguridad: si con prefiltro quedan 0 matches, hacemos fallback a base_scope (sin perder resultados).
  prefilter_token =
    if input_name.present?
      # toma el token más largo para maximizar selectividad (>= 4)
      input_name.split(/\s+/).map(&:strip).select { |t| t.length >= 4 }.max_by(&:length)
    else
      # modo segmentado: usa lastname1/lastname2 (>= 2)
      [input_lastname1, input_lastname2].compact.map(&:strip).select { |t| t.length >= 2 }.max_by(&:length)
    end

  prefiltered_scope =
    if prefilter_token.present?
      q = "%#{prefilter_token.downcase}%"
      base_scope
        .left_joins(:fake_identities)
        .where(
          "LOWER(members.firstname) LIKE :q OR LOWER(members.lastname1) LIKE :q OR LOWER(members.lastname2) LIKE :q OR LOWER(members.alias) LIKE :q OR " \
          "LOWER(fake_identities.firstname) LIKE :q OR LOWER(fake_identities.lastname1) LIKE :q OR LOWER(fake_identities.lastname2) LIKE :q",
          q: q
        )
        .distinct
    else
      base_scope
    end

  # === Fase 1 (ligera): cargar candidatos mínimos + fake_identities ===
  def load_candidates(scope)
    scope
      .select(:id, :firstname, :lastname1, :lastname2, :alias)
      .preload(:fake_identities)
      .to_a
  end

  t_a = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  candidates = load_candidates(prefiltered_scope)
  Rails.logger.info("[#{request.request_id}] PERF A candidates_loaded=#{candidates.size} ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC)-t_a)*1000).round} prefilter=#{prefilter_token.presence || "none"}")

  # === Matching (Ruby) ===
  t_b = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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

  # === Fallback: si el prefiltro dio 0 matches, reintenta sin prefiltro (para no perder resultados) ===
  if potential_match_ids.empty? && prefilter_token.present?
    t_f = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    candidates = load_candidates(base_scope)

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

    Rails.logger.info("[#{request.request_id}] PERF B_fallback matches=#{potential_match_ids.size} ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC)-t_f)*1000).round}")
  end

  Rails.logger.info("[#{request.request_id}] PERF B matches=#{potential_match_ids.size} ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC)-t_b)*1000).round}")

  # === Fase 2 (pesada): cargar asociaciones completas SOLO para matches ===
  potential_matches =
    if potential_match_ids.empty?
      []
    else
      Member.where(id: potential_match_ids).includes(
        :fake_identities,
        :notes,
        :organization,
        :criminal_link,
        hits: { town: { county: :state } },
        titles: [:organization, :year],
        appointments: [:organization, :role]
      ).to_a
    end

  # --- 5) Guardado / auditoría ---
  dataset_last_updated_at = Member.maximum(:updated_at)
  query_record = Query.create!(
    firstname: qp[:firstname],
    lastname1: qp[:lastname1],
    lastname2: qp[:lastname2],
    homo_score: homo_score,
    outcome: potential_match_ids,
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

  input_norm =
    if qp[:name].present?
      { mode: :name, name: normalize(qp[:name]) }
    else
      {
        mode: :segmented,
        firstname: normalize(qp[:firstname]),
        lastname1: normalize(qp[:lastname1]),
        lastname2: normalize(qp[:lastname2])
      }
    end

  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # --- 6) Payload members ---
  members_payload = potential_matches.map do |m|
    rolegroup = clasificar_rol(m)
    MemberOutcomeSerializer.new(m, rolegroup: rolegroup, input_norm: input_norm).as_json
  end

  Rails.logger.info("[#{request.request_id}] PERF C payload=#{members_payload.size} ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC)-t1)*1000).round}")

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
        return nil if score.nil?

        s = score.to_i

        if s < 2
          "low"        # incluye 0 y 1
        elsif s < 5
          "medium"
        elsif s <= 10
          "high"
        else
          "very_high"
        end
      end

      def pick_best_key(keys, norm)
        return norm if keys.include?(norm)

        contained = keys.select { |k| norm.include?(k) }
        return contained.max_by(&:length) if contained.any?

        containing = keys.select { |k| k.include?(norm) }
        containing.max_by(&:length)
      end

      def token_freq(names_norm, keys, token_norm)
        best = pick_best_key(keys, token_norm)
        best ? names_norm[best] : 5
      end

      def compound_freq(names_norm, keys, raw)
        norm = normalize(raw)
        parts = norm.split(/\s+/).reject(&:blank?)
        return token_freq(names_norm, keys, norm) if parts.length <= 1

        part_freqs = parts.map { |p| token_freq(names_norm, keys, p) }
        maxf = part_freqs.max || 5
        avgf = part_freqs.sum.to_f / part_freqs.length

        bonus = [0.10 * (parts.length - 1), 0.30].min
        ([avgf, maxf].max * (1.0 + bonus)).round
      end

        # En modo name: exact match manda. Inclusion solo como fallback y con descuento.
        def token_freq_strict(names_norm, keys, token_norm)
          return 5 if token_norm.blank?

          # exact
          return names_norm[token_norm] if names_norm.key?(token_norm)

          # fallback por inclusion (pero penalizado)
          contained = keys.select { |k| token_norm.include?(k) }
          best = if contained.any?
            contained.max_by(&:length)
          else
            containing = keys.select { |k| k.include?(token_norm) }
            containing.max_by(&:length)
          end

          base = best ? names_norm[best] : 5
          # Penaliza fuerte porque no fue exacto (ajusta 0.25 a 0.10–0.40 según gusto)
          (base * 0.25).round
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

          # Penalización por tokens extra (4+)
          extras = [tokens.length - 3, 0].max
          penalty = (0.60 ** extras)

          (base * penalty).round
        end

    end
  end
end
