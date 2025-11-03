namespace :ahoy do
  desc "Backfill geocoding data for visits in background"
  task backfill_geocoding: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    all = ENV["ALL"] == "true"

    if dry_run
      puts "Running dry run#{' (all visits)' if all}..."
      BackfillGeocodingJob.new.perform(dry_run: true, all: all)
    else
      puts "Enqueuing background job#{' (all visits)' if all}..."
      BackfillGeocodingJob.perform_later(all: all)
      puts "Job enqueued! Check logs for progress."
    end
  end
end
