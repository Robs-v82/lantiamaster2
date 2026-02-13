# lib/tasks/hit_snapshot_sample.rake

namespace :hits do
  desc "Run HitSnapshotFetcher on a random sample of N hits (default 100)"
  task :snapshot_sample, [:n] => :environment do |_, args|
    n = (args[:n].presence || 100).to_i

    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    random_sql =
      if adapter.include?("postgres")
        "RANDOM()"
      elsif adapter.include?("mysql")
        "RAND()"
      else
        "RANDOM()"
      end

    scope = Hit.where.not(link: [nil, ""])
    hits  = scope.order(Arel.sql(random_sql)).limit(n)

    puts "Sampling #{hits.size} hits..."

    ok = 0
    no_snapshot = 0
    errors = 0

    hits.find_each do |hit|
      begin
        HitSnapshotFetcher.call!(hit)

        has_html = hit.reload.raw_html.present?
        has_pdf  = hit.pdf_snapshot.attached?

        if has_html || has_pdf
          ok += 1
        else
          no_snapshot += 1
          puts "NO_SNAPSHOT hit_id=#{hit.id} status=#{hit.fetch_status.inspect} err=#{hit.fetch_error.inspect}"
        end
      rescue => e
        errors += 1
        puts "EXCEPTION hit_id=#{hit.id} #{e.class}: #{e.message}"
      end
    end

    puts "Done."
    puts "OK: #{ok}"
    puts "NO_SNAPSHOT: #{no_snapshot}"
    puts "EXCEPTIONS: #{errors}"
  end
end