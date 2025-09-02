namespace :subscriptions do
  desc "Expira suscripciones vencidas y baja users.membership_type a 1"
  task expire: :environment do
    now_mx = Time.use_zone("America/Mexico_City"){ Time.zone.now }
    scope = Subscription.where(status: "active").where("current_period_end <= ?", now_mx)
    puts "A expirar: #{scope.count}"
    scope.find_each(batch_size: 100) do |s|
      Subscription.transaction do
        s.update!(status: "canceled")
        User.where(id: s.user_id).where.not(membership_type: 1)
            .update_all(membership_type: 1, updated_at: Time.current)
      end
    end
    puts "Listo"
  end
end
