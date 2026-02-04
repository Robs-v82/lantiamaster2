namespace :queries do
  desc "Backfill encrypted fields + blind index for queries, then nullify plain columns"
  task backfill_encrypted: :environment do
    Query.reset_column_information

    Query.in_batches(of: 500) do |batch|
      batch.each do |q|
        label =
          q.query_label.presence ||
          [q.firstname, q.lastname1, q.lastname2].compact.join(" ").strip

        touched = false

        if label.present?
          q.query_label = label
          touched = true
        end

        if q.firstname.present?
          q.firstname = q.firstname
          touched = true
        end

        if q.lastname1.present?
          q.lastname1 = q.lastname1
          touched = true
        end

        if q.lastname2.present?
          q.lastname2 = q.lastname2
          touched = true
        end

        if q.outcome.present?
          q.outcome = q.outcome
          touched = true
        end

        next unless touched

        q.save!(validate: false)

        q.update_columns(
          firstname: nil,
          lastname1: nil,
          lastname2: nil,
          query_label: nil,
          outcome: nil
        )
      end
    end
  end
end