class Access::MembershipGate
  TZ = "America/Mexico_City"

  def self.active?(user)
    !!active_subscription(user)
  end

  def self.current_plan_id(user)
    active_subscription(user)&.plan&.level
  end

  def self.current_expiration(user)
    active_subscription(user)&.current_period_end&.in_time_zone(TZ)
  end

  def self.now_mx
    Time.use_zone(TZ) { Time.zone.now }
  end

  def self.active_subscription(user)
    Subscription.includes(:plan)
      .where(user_id: user.id, status: "active")
      .where("current_period_end > ?", now_mx)
      .order(current_period_end: :desc)
      .first
  end
end
