class GuildSyncPocJob < ApplicationJob
  queue_as :default

  def perform(response_url)
    guilds = Guild.open.includes(guild_signups: :user).to_a
    synced = 0
    failed = 0
    marked_pending = 0
    birthdays_backfilled = 0

    guilds.each do |guild|
      begin
        unless guild.guild_signups.any?(&:organizer?)
          guild.update!(status: :pending)
          marked_pending += 1
        end

        organizer_user = guild.guild_signups.find(&:organizer?)&.user
        if organizer_user&.birthday.nil? && organizer_user&.idv_linked?
          birthdays_backfilled += 1 if backfill_birthday_from_idv(organizer_user)
        end

        AirtableSync.sync_records!(Guild, [ guild ])
        synced += 1
      rescue => e
        Rails.logger.error "[GuildSyncPoc] Failed to sync guild #{guild.id} (#{guild.city}): #{e.message}"
        failed += 1
      end
    end

    result = "POC sync complete: #{synced} synced, #{failed} failed, #{marked_pending} marked pending (no organizer), #{birthdays_backfilled} birthdays backfilled out of #{guilds.size} open guilds"

    post_to_response_url(response_url, result)
  end

  private

  def backfill_birthday_from_idv(user)
    idv_data = user.fetch_idv
    raw_birthday = idv_data.dig(:identity, :birthday)
    return false unless raw_birthday.present?

    parsed = Date.iso8601(raw_birthday.to_s)
    return false unless parsed <= Date.current && parsed > 120.years.ago.to_date

    user.update!(birthday: parsed)
    true
  rescue ArgumentError, StandardError => e
    Rails.logger.warn "[GuildSyncPoc] Failed to backfill birthday for user #{user.id}: #{e.message}"
    false
  end

  def post_to_response_url(response_url, text)
    uri = URI.parse(response_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = { response_type: "in_channel", text: text }.to_json
    http.request(request)
  rescue => e
    Rails.logger.error "[GuildSyncPoc] Failed to post result to response_url: #{e.message}"
  end
end
