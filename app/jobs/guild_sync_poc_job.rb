class GuildSyncPocJob < ApplicationJob
  queue_as :default

  def perform(response_url)
    guilds = Guild.active.includes(guild_signups: :user).to_a
    synced = 0
    failed = 0

    guilds.each do |guild|
      begin
        AirtableSync.sync_records!(Guild, [ guild ])
        synced += 1
      rescue => e
        Rails.logger.error "[GuildSyncPoc] Failed to sync guild #{guild.id} (#{guild.city}): #{e.message}"
        failed += 1
      end
    end

    result = "POC sync complete: #{synced} synced, #{failed} failed out of #{guilds.size} active guilds"

    post_to_response_url(response_url, result)
  end

  private

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
