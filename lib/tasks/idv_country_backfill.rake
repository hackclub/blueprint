namespace :idv do
  desc "Backfill idv_country for users with IDV linked"
  task backfill_country: :environment do
    dry_run = ENV["DRY_RUN"].to_s.downcase == "true" || ENV["DRY_RUN"].to_s == "1"

    puts "Starting IDV country backfill - dry_run=#{dry_run}"
    puts

    users = User.where.not(identity_vault_access_token: nil).where(idv_country: nil)
    puts "Found #{users.count} users with IDV linked but no idv_country"

    success_count = 0
    error_count = 0

    users.find_each do |user|
      print "  User ##{user.id} (#{user.email}): "

      begin
        idv_data = user.fetch_idv
        addresses = idv_data.dig(:identity, :addresses) || []
        primary_address = addresses.find { |a| a[:primary] } || addresses.first || {}
        country = primary_address.dig(:country)

        if country.present?
          if dry_run
            puts "would set idv_country=#{country}"
          else
            user.update_column(:idv_country, country)
            puts "set idv_country=#{country}"
          end
          success_count += 1
        else
          puts "no country found in IDV data"
        end
      rescue => e
        puts "error: #{e.message}"
        error_count += 1
      end
    end

    puts
    puts "Done. (dry_run=#{dry_run})"
    puts "  Success: #{success_count}"
    puts "  Errors: #{error_count}"
  end
end
