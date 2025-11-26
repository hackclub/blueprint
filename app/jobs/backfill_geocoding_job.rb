class BackfillGeocodingJob < ApplicationJob
  queue_as :background

  RATE_LIMIT = 20 # requests per second globally

  # Cloudflare IP ranges (IPv4 and IPv6)
  CLOUDFLARE_IP_RANGES = [
    # IPv6
    IPAddr.new("2400:cb00::/32"),
    IPAddr.new("2606:4700::/32"),
    IPAddr.new("2803:f800::/32"),
    IPAddr.new("2405:b500::/32"),
    IPAddr.new("2405:8100::/32"),
    IPAddr.new("2a06:98c0::/29"),
    IPAddr.new("2c0f:f248::/32"),
    # IPv4
    IPAddr.new("173.245.48.0/20"),
    IPAddr.new("103.21.244.0/22"),
    IPAddr.new("103.22.200.0/22"),
    IPAddr.new("103.31.4.0/22"),
    IPAddr.new("141.101.64.0/18"),
    IPAddr.new("108.162.192.0/18"),
    IPAddr.new("190.93.240.0/20"),
    IPAddr.new("188.114.96.0/20"),
    IPAddr.new("197.234.240.0/22"),
    IPAddr.new("198.41.128.0/17"),
    IPAddr.new("162.158.0.0/15"),
    IPAddr.new("104.16.0.0/13"),
    IPAddr.new("104.24.0.0/14"),
    IPAddr.new("172.64.0.0/13"),
    IPAddr.new("131.0.72.0/22")
  ].freeze

  def perform(dry_run: false, all: false)
    max_threads = ENV.fetch("MAX_BACKGROUND_JOB_THREADS", "6").to_i.clamp(1, 6)

    scope = all ? Ahoy::Visit.where.not(ip: nil) : Ahoy::Visit.where(country: nil).where.not(ip: nil)
    all_visits_unfiltered = scope.to_a
    total_visits_unfiltered = all_visits_unfiltered.count
    total_ips_unfiltered = all_visits_unfiltered.map(&:ip).uniq.count

    all_visits = all_visits_unfiltered # .reject { |v| cloudflare_ip?(v.ip) }

    # Group by IP to only geocode each unique IP once
    visits_by_ip = all_visits.group_by(&:ip)
    unique_ips = visits_by_ip.keys
    total_visits = all_visits.count
    total_ips = unique_ips.count

    if dry_run
      Rails.logger.info "DRY RUN Results (#{all ? 'all visits' : 'only ungeocoded visits'}):"
      Rails.logger.info "  Before filtering: #{total_ips_unfiltered} unique IPs, #{total_visits_unfiltered} visits"
      Rails.logger.info "  After filtering:  #{total_ips} unique IPs, #{total_visits} visits"
      Rails.logger.info "  Filtered out:     #{total_ips_unfiltered - total_ips} Cloudflare IPs, #{total_visits_unfiltered - total_visits} visits"
      return
    end

    return if total_ips.zero?

    Rails.logger.info "Using #{max_threads} threads for geocoding backfill"
    Rails.logger.info "Backfilling geocoding for #{total_ips} unique IPs (#{total_visits} total visits)..."

    # Separate mutexes to avoid blocking counter updates while rate limiting
    rate_mutex = Mutex.new
    rate_cond = ConditionVariable.new
    counters_mutex = Mutex.new

    counters = { processed: 0, successes: 0, errors: 0, visits_updated: 0 }
    rate_limit_state = { count: 0, window_start: mono_now }

    unique_ips.each_slice((unique_ips.size.to_f / max_threads).ceil).map do |ip_batch|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ip_batch.each do |ip|
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
              result = Geocoder.search(ip).first

              if result
                # Update all visits with this IP
                visits_to_update = visits_by_ip[ip]
                visits_to_update.each do |visit|
                  visit.update_columns(
                    country: result.country_code,
                    region: result.state,
                    city: result.city,
                    latitude: result.latitude,
                    longitude: result.longitude
                  )
                end
                counters_mutex.synchronize do
                  counters[:successes] += 1
                  counters[:visits_updated] += visits_to_update.count
                end
              end
            rescue => e
              Rails.logger.error "Error geocoding IP #{ip}: #{e.message}"
              counters_mutex.synchronize { counters[:errors] += 1 }
            end

            counters_mutex.synchronize do
              counters[:processed] += 1
              if counters[:processed] % 100 == 0
                Rails.logger.info "Progress: #{counters[:processed]}/#{total_ips} IPs (#{counters[:successes]} successful, #{counters[:visits_updated]} visits updated, #{counters[:errors]} errors)"
              end
            end
          end
        end
      end
    end.each(&:join)

    Rails.logger.info "Backfill complete! Processed: #{counters[:processed]} IPs, Successful: #{counters[:successes]}, Visits updated: #{counters[:visits_updated]}, Errors: #{counters[:errors]}"
  end

  private

  def mono_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def cloudflare_ip?(ip_string)
    return false if ip_string.blank?

    ip = IPAddr.new(ip_string)
    CLOUDFLARE_IP_RANGES.any? { |range| range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end
end
