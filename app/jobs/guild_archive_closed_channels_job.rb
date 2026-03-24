class GuildArchiveClosedChannelsJob < ApplicationJob
  queue_as :default

  def perform(response_url)
    guilds = Guild.where(status: :closed).where.not(slack_channel_id: [nil, ""])
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])

    archived = 0
    already_archived = 0
    failed = 0

    guilds.find_each do |guild|
      begin
        slack_client.conversations_archive(channel: guild.slack_channel_id)
        Rails.logger.info "[GuildArchiveClosedChannels] Archived channel #{guild.slack_channel_id} for guild #{guild.id} (#{guild.city})"
        archived += 1
      rescue Slack::Web::Api::Errors::AlreadyArchived
        Rails.logger.info "[GuildArchiveClosedChannels] Channel #{guild.slack_channel_id} for guild #{guild.id} (#{guild.city}) already archived"
        already_archived += 1
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "[GuildArchiveClosedChannels] Failed to archive channel #{guild.slack_channel_id} for guild #{guild.id} (#{guild.city}): #{e.message}"
        failed += 1
      end
    end

    result = "Archived #{archived} channel(s) from #{guilds.count} closed guild(s)."
    result += " #{already_archived} already archived." if already_archived > 0
    result += " #{failed} failed." if failed > 0

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
    Rails.logger.error "[GuildArchiveClosedChannels] Failed to post result to response_url: #{e.message}"
  end
end
