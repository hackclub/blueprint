class BackfillGeocodingJob < ApplicationJob
  queue_as :background

  RATE_LIMIT = 20 # requests per second

  def perform(batch_size: 100)
    visits = Ahoy::Visit.where(country: nil).where.not(ip: nil)
    total = visits.count

    Rails.logger.info "Backfilling geocoding for #{total} visits in batches of #{batch_size}..."

    processed = 0
    errors = 0
    successes = 0
    request_count = 0
    window_start = Time.current

    visits.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |visit|
        # Rate limiting: allow bursts up to 20 per second
        if request_count >= RATE_LIMIT
          elapsed = Time.current - window_start
          if elapsed < 1
            sleep_time = 1 - elapsed
            sleep(sleep_time)
          end
          request_count = 0
          window_start = Time.current
        end

        begin
          result = Geocoder.search(visit.ip).first
          request_count += 1

          if result
            visit.update_columns(
              country: result.country_code,
              region: result.state,
              city: result.city,
              latitude: result.latitude,
              longitude: result.longitude
            )
            successes += 1
          end
        rescue => e
          Rails.logger.error "Error geocoding visit #{visit.id}: #{e.message}"
          errors += 1
        end

        processed += 1

        if processed % 100 == 0
          Rails.logger.info "Progress: #{processed}/#{total} (#{successes} successful, #{errors} errors)"
        end
      end
    end

    Rails.logger.info "Backfill complete! Processed: #{processed}, Successful: #{successes}, Errors: #{errors}"
  end
end
