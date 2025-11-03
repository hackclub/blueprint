namespace :ahoy do
  desc "Backfill geocoding data for visits in background"
  task backfill_geocoding: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    if dry_run
      puts "Running dry run..."
      BackfillGeocodingJob.new.perform(dry_run: true)
    else
      puts "Enqueuing background job..."
      BackfillGeocodingJob.perform_later
      puts "Job enqueued! Check logs for progress."
    end
  end
end
