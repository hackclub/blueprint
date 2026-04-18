class GuildSlackInviteJob < ApplicationJob
  queue_as :default

  def perform(signup_id)
    signup = GuildSignup.find_by(id: signup_id)
    return unless signup
    return if signup.volunteer?

    guild = signup.guild
    user = signup.user
    return unless user&.slack_id.present?

    ensure_guild_channel!(guild)
    guild.reload

    return unless guild.slack_channel_id.present?

    invite_to_channel(guild.slack_channel_id, user)
    invite_to_channel(Guild::MAIN_CHANNEL_ID, user)

    if signup.organizer?
      organizers_channel = ENV["GUILDS_ORGANIZERS_CHANNEL"]
      invite_to_channel(organizers_channel, user) if organizers_channel.present?
      guild.update_slack_topic
    end

    post_welcome_message(guild, user, signup)
    send_dm(guild, user, signup)
  end

  private

  def ensure_guild_channel!(guild)
    return if guild.slack_channel_id.present?

    channel_name = "build-guild-#{guild.city.parameterize}"
    begin
      response = slack_client.conversations_create(name: channel_name)
      guild.update!(slack_channel_id: response["channel"]["id"])
    rescue Slack::Web::Api::Errors::NameTaken
      existing = find_existing_channel(channel_name)
      guild.update!(slack_channel_id: existing["id"]) if existing
    rescue Slack::Web::Api::Errors::SlackError
      notify_admin("Failed to create Slack channel for guild #{guild.city}")
    end
  end

  def find_existing_channel(name)
    cursor = nil
    loop do
      response = slack_client.conversations_list(types: "public_channel", limit: 200, cursor: cursor)
      found = response["channels"]&.find { |c| c["name"] == name }
      return found if found
      cursor = response.dig("response_metadata", "next_cursor")
      break if cursor.blank?
    end
    nil
  end

  def invite_to_channel(channel_id, user)
    slack_client.conversations_invite(channel: channel_id, users: user.slack_id)
  rescue Slack::Web::Api::Errors::AlreadyInChannel
  rescue Slack::Web::Api::Errors::UserIsRestricted
    notify_admin("<@#{user.slack_id}> is a multi-channel guest, cannot invite to <##{channel_id}>")
  rescue Slack::Web::Api::Errors::SlackError => e
    notify_admin("Failed to invite <@#{user.slack_id}> to <##{channel_id}>: #{e.message}")
  end

  def post_welcome_message(guild, user, signup)
    return unless guild.slack_channel_id.present?

    role_text = signup.organizer? ? "an organizer" : "an attendee"
    message = "Hey <@#{user.slack_id}>! Welcome to the #{guild.city} Build Guild channel. You're signed up as #{role_text}!"
    slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
  rescue Slack::Web::Api::Errors::SlackError => e
    notify_admin("Failed to post welcome message to <##{guild.slack_channel_id}> for <@#{user.slack_id}>: #{e.message}")
  end

  def send_dm(guild, user, signup)
    dm_response = slack_client.conversations_open(users: user.slack_id)
    dm_channel = dm_response["channel"]["id"]

    dm_text = if signup.organizer?
      organizers_channel = ENV["GUILDS_ORGANIZERS_CHANNEL"]
      "You've signed up to organize a Build Guild in #{guild.city}! We've created a channel <##{guild.slack_channel_id}> for planning and communication with attendees. You've also been added to the central organizers channel <##{organizers_channel}> where you can talk with other organizers and ask any questions you might have about running your guild!"
    else
      "You've signed up to attend the Build Guild in #{guild.city}! We've added you to the channel <##{guild.slack_channel_id}> where you can talk to organizers and other attendees."
    end

    slack_client.chat_postMessage(channel: dm_channel, text: dm_text)
  rescue Slack::Web::Api::Errors::SlackError => e
    notify_admin("Failed to send DM to <@#{user.slack_id}> for #{guild.city} signup: #{e.message}")
  end

  def notify_admin(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue
  end

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
  end
end
