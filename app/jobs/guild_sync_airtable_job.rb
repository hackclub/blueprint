class GuildSyncAirtableJob < ApplicationJob
  queue_as :background

  def perform(response_url)
    guild_count = Guild.count
    signup_count = GuildSignup.count
    results = []

    Rails.logger.info "[GuildSyncAirtable] Starting sync: #{guild_count} guilds, #{signup_count} signups"

    begin
      Rails.logger.info "[GuildSyncAirtable] Syncing guilds..."
      AirtableSync.sync!("Guild", sync_all: true)
      Rails.logger.info "[GuildSyncAirtable] Guilds synced successfully"
      results << "Guilds: #{guild_count} synced"
    rescue => e
      Rails.logger.error "[GuildSyncAirtable] Guild sync failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      results << "Guilds: failed (#{e.message})"
    end

    begin
      Rails.logger.info "[GuildSyncAirtable] Syncing signups..."
      AirtableSync.sync!("GuildSignup", sync_all: true)
      Rails.logger.info "[GuildSyncAirtable] Signups synced successfully"
      results << "Signups: #{signup_count} synced"
    rescue => e
      Rails.logger.error "[GuildSyncAirtable] Signup sync failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      results << "Signups: failed (#{e.message})"
    end

    summary = results.join("\n")
    Rails.logger.info "[GuildSyncAirtable] Done. #{summary}"
    post_to_response_url(response_url, "Sync complete.\n#{summary}")
  rescue => e
    Rails.logger.error "[GuildSyncAirtable] Job failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    post_to_response_url(response_url, "Sync failed: #{e.message}") if response_url.present?
    raise
  end

  private

  def post_to_response_url(response_url, text)
    return unless response_url.present?

    uri = URI.parse(response_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = { response_type: "in_channel", text: text }.to_json
    http.request(request)
  rescue => e
    Rails.logger.error "[GuildSyncAirtable] Failed to post result to response_url: #{e.message}"
  end
end
