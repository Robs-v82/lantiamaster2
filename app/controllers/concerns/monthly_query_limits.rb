module MonthlyQueryLimits
  extend ActiveSupport::Concern

  def consultas_mensuales(user)
    return { usuario: 0, organizacion: 0, total: 0, total_org: 0 } unless user&.member&.organization

    inicio_de_mes = Time.current.beginning_of_month
    fin_de_mes = Time.current.end_of_month
    org = user.member.organization

    queries_usuario = user.queries.where(created_at: inicio_de_mes..fin_de_mes).count

    queries_organizacion = Query.where(user_id: org.users.where.not(id: user.id).pluck(:id))
      .where(created_at: inicio_de_mes..fin_de_mes)
      .count

    total_org = Query.where(user_id: org.users.pluck(:id))
      .where(created_at: inicio_de_mes..fin_de_mes)
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
    when 1
    { level: "básica", points: 15 }
      when 2
    { level: "avanzada", points: 500 }
      when 3
    { level: "premium", points: 1000 }
    else
      { level: "sin suscripción", points: 0 }
    end
  end

  def enforce_monthly_limit!(user)
    suscription = set_suscription(user)
    info = consultas_mensuales(user)

    if info[:total_org] >= suscription[:points]
      session[:plan_limit_error] = true
      redirect_to action: :members_search
      return false
    end
    true
  end

end
