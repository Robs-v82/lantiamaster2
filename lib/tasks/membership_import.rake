# lib/tasks/membership_import.rake
namespace :membership do
  desc "Importa Plan y Subscription desde las tablas lrvl_* (DEV primero)"
  task import_lrvl: :environment do
    tz = "America/Mexico_City"
    puts "Importando planes…"
    LrvlMembership.find_each do |lm|
      days = lm.duration_year.to_i > 0 ? lm.duration_year.to_i : (lm.duration.to_i > 0 ? lm.duration.to_i : 30)
      Plan.find_or_create_by!(level: lm.id) do |p|
        p.name = lm.name
        p.duration_days = days
      end
    end

    puts "Importando suscripciones (última vigente por usuario)…"
    rows = LrvlMembershipExpiration.where(expirated: false)
                                   .order(user_id: :asc, expiration: :desc).to_a
    rows.group_by(&:user_id).each do |uid, arr|
      r = arr.first
      plan = Plan.find_by(level: r.membership_id)
      next unless plan
      exp = r.expiration.in_time_zone(tz)
      status = exp > Time.use_zone(tz){ Time.zone.now } ? "active" : "canceled"
      sub = Subscription.find_or_initialize_by(user_id: uid)
      sub.plan_id = plan.id
      sub.current_period_end = exp
      sub.status = status
      sub.save!
    end
    puts "OK"
  end
end