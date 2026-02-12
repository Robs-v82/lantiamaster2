namespace :hits do
  desc "Fetch snapshots for 50 hits with link (dev test)"
  task snapshot_dev: :environment do
    scope = Hit.where.not(link: [nil, ""])
               .where(raw_html: nil)
               .order(id: :desc)
               .limit(50)

    puts "Processing #{scope.count} hits..."

    scope.each_with_index do |hit, i|
      puts "[#{i+1}] Hit##{hit.id} - #{hit.link}"
      HitSnapshotFetcher.call!(hit)
      sleep 0.8
    end

    puts "Done."
  end
end