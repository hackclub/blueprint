class GuildMergeJob < ApplicationJob
  queue_as :default

  def perform(source_id, target_id, response_url)
    source = Guild.find(source_id)
    target = Guild.find(target_id)

    moved = 0
    skipped = 0
    moved_user_ids = []
    source.guild_signups.to_a.each do |signup|
      if target.guild_signups.exists?(user_id: signup.user_id)
        signup.destroy!
        skipped += 1
      else
        signup.update!(guild_id: target.id)
        moved_user_ids << signup.user_id
        moved += 1
      end
    end

    source.update!(status: :closed)
    Rails.logger.info "Merge complete: moved=#{moved} skipped=#{skipped} source_id=#{source.id} target_id=#{target.id}"

    invite_failures = 0
    if target.slack_channel_id.present? && moved_user_ids.any?
      slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
      User.where(id: moved_user_ids).where.not(slack_id: [ nil, "" ]).each do |user|
        begin
          slack_client.conversations_invite(channel: target.slack_channel_id, users: user.slack_id)
          Rails.logger.info "Invited user=#{user.id} (slack=#{user.slack_id}) to channel=#{target.slack_channel_id}"
        rescue Slack::Web::Api::Errors::AlreadyInChannel
          Rails.logger.info "User=#{user.id} already in channel=#{target.slack_channel_id}"
        rescue Slack::Web::Api::Errors::UserIsRestricted
          Rails.logger.warn "User=#{user.id} is a multi-channel guest, cannot invite to channel=#{target.slack_channel_id}"
          invite_failures += 1
        rescue Slack::Web::Api::Errors::SlackError => e
          Rails.logger.error "Failed to invite user=#{user.id} to channel=#{target.slack_channel_id}: #{e.message}"
          invite_failures += 1
        end
      end
    end

    if source.slack_channel_id.present?
      slack_client ||= Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
      target_channel_mention = target.slack_channel_id.present? ? "<##{target.slack_channel_id}>" : "*#{target.name}*"
      merge_message = "This guild has been merged into #{target_channel_mention}. " \
        "https://gas.hackclub.com/ can help you cover travel to the new guild!"
      begin
        slack_client.chat_postMessage(channel: source.slack_channel_id, text: merge_message, link_names: true)
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to post in the original channel=#{source.slack_channel_id} about merge: #{e.message}"
      end
    end

    target.update_slack_topic

    result = "Merged *#{source.name}* into *#{target.name}*. Moved #{moved} signup(s), removed #{skipped} duplicate(s). Source guild marked as closed."
    result += " #{invite_failures} user(s) could not be invited to <##{target.slack_channel_id}>." if invite_failures > 0

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
    Rails.logger.error "Failed to post merge result to response_url: #{e.message}"
  end
end
