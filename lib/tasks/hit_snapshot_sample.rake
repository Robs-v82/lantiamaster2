# lib/tasks/hit_snapshot_sample.rake

namespace :hits do
  desc "Run HitSnapshotFetcher on a random sample of N hits (default 100) with strict OK criteria"
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
    hits  = scope.order(Arel.sql(random_sql)).limit(n).to_a # <- to_a para fijar el sample

    puts "Sampling #{hits.size} hits..."

    ok = 0
    not_ok = 0
    exceptions = 0

    hits.each do |hit| # <- NO find_each (respeta el sample)
      begin
        pdf_before = hit.pdf_snapshot.attached?
        html_before = hit.raw_html.present?

        HitSnapshotFetcher.call!(hit)
        hit.reload

        has_html = hit.raw_html.present?
        has_pdf  = hit.pdf_snapshot.attached?
        pdf_created = (!pdf_before && has_pdf)
        html_created = (!html_before && has_html)

        # “Sin error” = nada que indique fallo
        no_error = hit.fetch_error.blank? && hit.backup_status != "error"

        # “OK estricto” = condiciones + respaldo + sin error
        strict_ok = (hit.backup_status == "ok") && no_error && (has_html || has_pdf)

        if strict_ok
          ok += 1
        else
          not_ok += 1
          puts "NOT_OK hit_id=#{hit.id} backup_status=#{hit.backup_status.inspect} fetch_error=#{hit.fetch_error.inspect} has_html=#{has_html} has_pdf=#{has_pdf} html_new=#{html_created} pdf_new=#{pdf_created}"
        end

      rescue => e
        exceptions += 1
        puts "EXCEPTION hit_id=#{hit.id} #{e.class}: #{e.message}"
      end
    end

    puts "Done."
    puts "OK(strict): #{ok}"
    puts "NOT_OK: #{not_ok}"
    puts "EXCEPTIONS: #{exceptions}"
  end
end