class BackfillGeocodingJob < ApplicationJob
  queue_as :background

  RATE_LIMIT = 20 # requests per second globally

  def perform
    max_threads = ENV.fetch("MAX_BACKGROUND_JOB_THREADS", "6").to_i.clamp(1, 6)
    Rails.logger.info "Using #{max_threads} threads for geocoding backfill"

    visits = Ahoy::Visit.where(country: nil).where.not(ip: nil).to_a
    total = visits.count

    return if total.zero?

    Rails.logger.info "Backfilling geocoding for #{total} visits..."

    # Separate mutexes to avoid blocking counter updates while rate limiting
    rate_mutex = Mutex.new
    rate_cond = ConditionVariable.new
    counters_mutex = Mutex.new

    counters = { processed: 0, successes: 0, errors: 0 }
    rate_limit_state = { count: 0, window_start: mono_now }

    visits.each_slice((visits.size.to_f / max_threads).ceil).map do |visit_batch|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          visit_batch.each do |visit|
            # Rate limiting: wait until we can make a request
            rate_mutex.synchronize do
              loop do
                now = mono_now
                elapsed = now - rate_limit_state[:window_start]

                # Reset window if more than 1 second has elapsed
                if elapsed >= 1
                  rate_limit_state[:window_start] = now
                  rate_limit_state[:count] = 0
                  rate_cond.broadcast
                end

                # If under limit, claim a slot and proceed
                if rate_limit_state[:count] < RATE_LIMIT
                  rate_limit_state[:count] += 1
                  break
                else
                  # Wait for remaining time in window (releases lock while waiting)
                  remaining = 1 - elapsed
                  rate_cond.wait(rate_mutex, remaining) if remaining > 0
                end
              end
            end

            begin
              result = Geocoder.search(visit.ip).first

              if result
                visit.update_columns(
                  country: result.country_code,
                  region: result.state,
                  city: result.city,
                  latitude: result.latitude,
                  longitude: result.longitude
                )
                counters_mutex.synchronize { counters[:successes] += 1 }
              end
            rescue => e
              Rails.logger.error "Error geocoding visit #{visit.id}: #{e.message}"
              counters_mutex.synchronize { counters[:errors] += 1 }
            end

            counters_mutex.synchronize do
              counters[:processed] += 1
              if counters[:processed] % 100 == 0
                Rails.logger.info "Progress: #{counters[:processed]}/#{total} (#{counters[:successes]} successful, #{counters[:errors]} errors)"
              end
            end
          end
        end
      end
    end.each(&:join)

    Rails.logger.info "Backfill complete! Processed: #{counters[:processed]}, Successful: #{counters[:successes]}, Errors: #{counters[:errors]}"
  end

  private

  def mono_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
