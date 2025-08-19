# Backfill Appointments desde Members con fechas completas y criminal_link presente

scope = Member
  .where.not(start_date: nil, end_date: nil, criminal_link: nil)
  .where.not(role_id: nil)

created = 0
skipped = 0
failed  = 0
processed = 0

scope.find_in_batches(batch_size: 500) do |batch|
  batch.each do |m|
    processed += 1
    begin
      sd = m.start_date.to_date
      ed = m.end_date.to_date

      # sanity check
      if ed < sd
        skipped += 1
        puts "[SKIP] member_id=#{m.id} end_date < start_date (#{ed} < #{sd})"
        next
      end

      # atributos base para el appointment
      attrs = {
        member: m,
        role_id: m.role_id,
        organization_id: m.organization_id,
        period: (sd...ed + 1.day),
        start_precision: :day,
        end_precision: :day
      }
      # si Member tiene county_id, lo copiamos
      attrs[:county_id] = m.county_id if m.respond_to?(:county_id) && m.county_id.present?

      # idempotencia: si ya existe exactamente igual, saltar
      exists_same = Appointment
        .where(member_id: m.id, role_id: m.role_id, organization_id: m.organization_id)
        .where("lower(period) = ? AND upper(period) = ?", sd, ed + 1.day)
        .exists?

      if exists_same
        skipped += 1
        next
      end

      Appointment.create!(**attrs)
      created += 1

    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      failed += 1
      puts "[FAIL] member_id=#{m.id} -> #{e.class}: #{e.message}"
    end
  end
end

puts "Backfill completado. Procesados: #{processed}, Creados: #{created}, Saltados: #{skipped}, Fallidos: #{failed}"
