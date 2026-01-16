module MonthlyQueryLimits
  extend ActiveSupport::Concern

  # Nuevo: cuenta consultas en el periodo que aplique al plan
  def consultas_en_periodo(user)
    return { usuario: 0, organizacion: 0, total: 0, total_org: 0 } unless user&.member&.organization

    org   = user.member.organization
    level = org.search_level.to_i
    start_at = org.subscription_started_at || Time.current

    if level.between?(1, 5)
      inicio = start_at
      fin    = start_at + 1.year
    elsif level == 6
      inicio = start_at
      fin    = start_at + 1.month

      # ✅ Trial expirado: baja a sin suscripción y corta aquí
      if Time.current >= fin
        org.update_columns(search_level: 0, subscription_started_at: nil)
        return { usuario: 0, organizacion: 0, total: 0, total_org: 0 }
      end
    else
      return { usuario: 0, organizacion: 0, total: 0, total_org: 0 }
    end

    queries_usuario = user.queries.where(created_at: inicio..fin).count

    queries_organizacion = Query.where(user_id: org.users.where.not(id: user.id).pluck(:id))
                                .where(created_at: inicio..fin)
                                .count

    total_org = Query.where(user_id: org.users.pluck(:id))
                     .where(created_at: inicio..fin)
                     .count

    {
      usuario: queries_usuario,
      organizacion: queries_organizacion,
      total: queries_usuario + queries_organizacion,
      total_org: total_org
    }
  end

  def set_suscription(user)
    org_level = user&.member&.organization&.search_level.to_i

    @suscription = case org_level
    when 1 then { level: "A", points: 1200,  period: :year }
    when 2 then { level: "B", points: 2400,  period: :year }
    when 3 then { level: "C", points: 6000,  period: :year }
    when 4 then { level: "D", points: 12000, period: :year }
    when 5 then { level: "E", points: 60000, period: :year }
    when 6 then { level: "prueba", points: 500, period: :month, renewable: false }
    else
      { level: "sin suscripción", points: 0, period: :none }
    end
  end

  def enforce_query_limit!(user) # (si quieres, luego lo renombramos)
    suscription = set_suscription(user)
    info = consultas_en_periodo(user)

    if info[:total_org] >= suscription[:points]
      session[:plan_limit_error] = true
      redirect_to action: :members_search
      return false
    end
    true
  end

  def ensure_trial_status!(user)
    org = user&.member&.organization
    return unless org
    return unless org.search_level.to_i == 6

    start_at = org.subscription_started_at
    return unless start_at

    if Time.current >= (start_at + 1.month)
      org.update_columns(search_level: 0, subscription_started_at: nil)
    end
  end

end
