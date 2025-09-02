namespace :membership do
  desc "Sincroniza users.membership_type con lrvl_membership_expiration"
  task sync_from_lrvl: :environment do
    now_mx = Time.use_zone("America/Mexico_City") { Time.zone.now }
    ts = ActiveRecord::Base.connection.quote(now_mx)

    # 1) Activos: setear plan vigente
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE users u
      SET membership_type = s.membership_id,
          updated_at = NOW()
      FROM (
        SELECT user_id, membership_id
        FROM lrvl_membership_expiration
        WHERE expirated = false AND expiration > #{ts}
      ) AS s
      WHERE u.id = s.user_id
        AND COALESCE(u.membership_type, 0) <> s.membership_id;
    SQL

    # 2) Expirados o sin registro vigente: bajar a 1
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE users u
      SET membership_type = 1,
          updated_at = NOW()
      WHERE COALESCE(u.membership_type, 0) <> 1
        AND NOT EXISTS (
          SELECT 1
          FROM lrvl_membership_expiration lme
          WHERE lme.user_id = u.id
            AND lme.expirated = false
            AND lme.expiration > #{ts}
        );
    SQL

    puts "Sync completo a #{now_mx}"
  end
end

