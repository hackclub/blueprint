class GuildSyncAirtableJob < ApplicationJob
  queue_as :background

  def perform(response_url)
    guild_count = Guild.count
    signup_count = GuildSignup.count

    AirtableSync.sync!("Guild", sync_all: true)
    AirtableSync.sync!("GuildSignup", sync_all: true)

    post_to_response_url(response_url, "sync complete. Synced #{guild_count} guilds and #{signup_count} signups.")
  rescue => e
    Rails.logger.error "[GuildSyncAirtable] Job failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    post_to_response_url(response_url, "sync failed: #{e.message}") if response_url.present?
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
