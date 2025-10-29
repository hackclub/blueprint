namespace :ahoy do
  desc "Backfill geocoding data for visits"
  task backfill_geocoding: :environment do
    visits = Ahoy::Visit.where(country: nil).where.not(ip: nil)
    total = visits.count

    puts "Backfilling geocoding for #{total} visits..."
    puts "Rate limit: 20 requests/second (0.05s delay between requests)"

    visits.find_each.with_index do |visit, index|
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
          print "."
        else
          print "x"
        end
      rescue => e
        puts "\nError geocoding visit #{visit.id}: #{e.message}"
        print "!"
      end

      # Rate limit: 20 requests per second = 0.05 seconds between requests
      sleep 0.05

      puts " #{index + 1}/#{total}" if (index + 1) % 100 == 0
    end

    puts "\nDone!"
  end
end
