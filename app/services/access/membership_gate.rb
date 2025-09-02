# app/services/access/membership_gate.rb
class Access::MembershipGate
  TZ = "America/Mexico_City"

  def self.active?(user)
    exp = current_expiration(user)
    exp && exp > Time.use_zone(TZ) { Time.zone.now }
  end

  def self.current_plan_id(user)
    row = LrvlMembershipExpiration.where(user_id: user.id, expirated: false)
                                  .order(expiration: :desc).first
    row&.membership_id
  end

  def self.current_expiration(user)
    row = LrvlMembershipExpiration.where(user_id: user.id, expirated: false)
                                  .order(expiration: :desc).first
    row&.expiration&.in_time_zone(TZ)
  end
end
