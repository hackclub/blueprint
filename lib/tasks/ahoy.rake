namespace :ahoy do
  desc "Backfill geocoding data for visits in background"
  task backfill_geocoding: :environment do
    count = Ahoy::Visit.where(country: nil).where.not(ip: nil).count
    puts "Enqueuing background job to geocode #{count} visits..."
    BackfillGeocodingJob.perform_later
    puts "Job enqueued! Check logs for progress."
  end
end
