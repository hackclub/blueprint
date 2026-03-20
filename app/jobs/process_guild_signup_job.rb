class ProcessGuildSignupJob < ApplicationJob
  queue_as :default

  MAX_ORGANIZERS = 2

  def perform(signup_id)
    signup = GuildSignup.find_by(id: signup_id)
    return unless signup
    guild = signup.guild
    user = signup.user

    if guild.needs_review?
      Rails.logger.info "Guild #{guild.id} flagged for review – skipping Slack actions for signup #{signup.id}."
      notify_admin(ENV["GUILDS_ADMIN_CHANNEL"], "New signup held: *#{user.display_name}* (#{signup.role}) for *#{guild.city}*. Guild needs review.")
      return
    end

    notify_admin(ENV["GUILDS_ADMIN_CHANNEL"], "New #{signup.role} signup: *#{user.display_name}* for *#{guild.city}*")

    admin_channel = ENV["GUILDS_ADMIN_CHANNEL"]
    organizers_channel = ENV["GUILDS_ORGANIZERS_CHANNEL"]
    contact_slack_id = "U08350QEPM1"

    converted = false
    if signup.organizer?
      guild.with_lock do
        existing = guild.guild_signups
                       .where(role: :organizer)
                       .where.not(id: signup.id)
                       .count
        if existing >= MAX_ORGANIZERS
          signup.update!(role: :attendee)
          converted = true
          Rails.logger.info "Converted signup #{signup.id} to attendee (exceeded max organizers)"
          notify_admin(admin_channel, "User #{user.display_name} signed up as organizer for #{guild.city} but max organizers (#{MAX_ORGANIZERS}) exceeded. Converted to attendee.")
        end
      end
    end

    signup.reload

    ensure_guild_channel!(guild, signup, user, admin_channel)
    guild.reload

    invite_to_guild_channel(guild, user, signup, admin_channel)
    invite_to_main_channel(user, admin_channel)

    guild.update_slack_topic if signup.organizer? && guild.slack_channel_id.present?

    if signup.organizer? && guild.pending? && guild.guild_signups.where(role: :organizer).count == 1
      guild.update(status: :active)
      Rails.logger.info "Guild #{guild.id} marked as active (first organizer signup)"
      notify_admin(admin_channel, "*#{guild.name}* is now active (first organizer signed up)")
    end

    invite_to_organizers_channel(guild, user, signup, organizers_channel, admin_channel)
    post_welcome_message(guild, user, signup, admin_channel)
    post_no_organizers_message(guild, signup, contact_slack_id)
    send_dm(guild, user, signup, converted, organizers_channel, admin_channel)

  rescue => e
    Rails.logger.error "ProcessGuildSignupJob failed: #{e.message}"
    notify_admin(admin_channel, "ProcessGuildSignupJob failed for signup #{signup_id}: #{e.message}")
    raise
  end

  private

  def ensure_guild_channel!(guild, signup, user, admin_channel)
    return if guild.slack_channel_id.present?

    channel_name = "build-guild-#{guild.city.parameterize}"
    begin
      response = slack_client.conversations_create(name: channel_name)
      guild.update!(slack_channel_id: response["channel"]["id"])
      notify_admin(admin_channel, "New guild channel created: <##{guild.slack_channel_id}> for #{guild.city} (triggered by #{signup.role}: #{user.display_name})")
    rescue Slack::Web::Api::Errors::NameTaken
      # Channel already exists, try to find it
      existing = nil
      cursor = nil
      loop do
        response = slack_client.conversations_list(types: "public_channel", limit: 200, cursor: cursor)
        existing = response["channels"]&.find { |c| c["name"] == channel_name }
        break if existing
        cursor = response.dig("response_metadata", "next_cursor")
        break if cursor.blank?
      end
      if existing
        guild.update!(slack_channel_id: existing["id"])
        Rails.logger.info "Found existing Slack channel #{channel_name} for guild #{guild.id}"
        notify_admin(admin_channel, "Reused existing Slack channel <##{existing["id"]}> for #{guild.city} (channel already existed)")
      else
        Rails.logger.error "Channel name '#{channel_name}' taken but not found in channel list for guild #{guild.id}"
        notify_admin(admin_channel, "Channel name '#{channel_name}' is taken but couldn't be found")
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Failed to create Slack channel for guild #{guild.id}: #{e.message}"
      notify_admin(admin_channel, "Failed to create Slack channel for #{guild.city}: #{e.message}")
    end
  end

  def invite_to_guild_channel(guild, user, signup, admin_channel)
    return unless guild.slack_channel_id.present?

    if user.slack_id.present?
      begin
        slack_client.conversations_invite(channel: guild.slack_channel_id, users: user.slack_id)
        notify_admin(admin_channel, "Invited <@#{user.slack_id}> to <##{guild.slack_channel_id}> (role: #{signup.role})")
      rescue Slack::Web::Api::Errors::AlreadyInChannel
        Rails.logger.info "User #{user.id} already in channel #{guild.slack_channel_id}"
      rescue Slack::Web::Api::Errors::UserIsRestricted
        Rails.logger.warn "User #{user.id} is a multi-channel guest, cannot invite to #{guild.slack_channel_id}"
        notify_admin(admin_channel, "<@#{user.slack_id}> is a multi-channel guest and cannot be invited to <##{guild.slack_channel_id}> (role: #{signup.role}). They have been DM'd instructions to become a full member.")
        slack_client.chat_postMessage(
          channel: user.slack_id,
          text: "Hey! We couldn't add you to your guild's Slack channel because your account is a multi-channel guest. To get promoted to a full member, follow the instructions in this post: https://hackclub.slack.com/archives/C0A9PMV58R5/p1770294664806709"
        ) rescue nil
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to invite user #{user.id} to channel #{guild.slack_channel_id}: #{e.message}"
        notify_admin(admin_channel, "Failed to invite <@#{user.slack_id}> to <##{guild.slack_channel_id}> (role: #{signup.role}): #{e.message}")
      end
    else
      notify_admin(admin_channel, "User #{user.display_name} has no Slack ID – cannot invite to <##{guild.slack_channel_id}> (role: #{signup.role})")
    end
  end

  def invite_to_organizers_channel(guild, user, signup, organizers_channel, admin_channel)
    return unless signup.organizer? && organizers_channel.present?

    if user.slack_id.present?
      begin
        slack_client.conversations_invite(channel: organizers_channel, users: user.slack_id)
        notify_admin(admin_channel, "Invited <@#{user.slack_id}> to <##{organizers_channel}> (organizer for #{guild.city})")
      rescue Slack::Web::Api::Errors::AlreadyInChannel
        Rails.logger.info "User #{user.id} already in organizers channel"
      rescue Slack::Web::Api::Errors::UserIsRestricted
        Rails.logger.warn "User #{user.id} is a multi-channel guest, cannot invite to organizers channel"
        notify_admin(admin_channel, "<@#{user.slack_id}> is a multi-channel guest and cannot be invited to <##{organizers_channel}>. They have been Dm'd instructions to become a full member")
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to invite user #{user.id} to organizers channel: #{e.message}"
        notify_admin(admin_channel, "Failed to invite <@#{user.slack_id}> to <##{organizers_channel}>: #{e.message}")
      end
    else
      notify_admin(admin_channel, "User #{user.display_name} has no Slack ID - cannot invite to organizers channel")
    end
  end

  def invite_to_main_channel(user, admin_channel)
    return unless user.slack_id.present?

    slack_client.conversations_invite(channel: Guild::MAIN_CHANNEL_ID, users: user.slack_id)
  rescue Slack::Web::Api::Errors::AlreadyInChannel
    # already there
  rescue Slack::Web::Api::Errors::UserIsRestricted
    Rails.logger.warn "User #{user.id} is a multi-channel guest, cannot invite to #build-guilds"
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Failed to invite user #{user.id} to #build-guilds: #{e.message}"
    notify_admin(admin_channel, "Failed to invite <@#{user.slack_id}> to #build-guilds: #{e.message}")
  end

  def post_welcome_message(guild, user, signup, admin_channel)
    return unless guild.slack_channel_id.present? && user.slack_id.present?

    role_text = signup.organizer? ? "an organizer" : "an attendee"
    message = "Hey <@#{user.slack_id}>! Welcome to the #{guild.city} Build Guild channel. You're signed up as #{role_text}!"
    slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Failed to post welcome message to #{guild.slack_channel_id}: #{e.message}"
    notify_admin(admin_channel, "Failed to post welcome message to <##{guild.slack_channel_id}> for <@#{user.slack_id}>: #{e.message}")
  end

  def post_no_organizers_message(guild, signup, contact_slack_id)
    return if signup.organizer?
    return unless guild.slack_channel_id.present?
    return if guild.guild_signups.where(role: :organizer).exists?

    if contact_slack_id.present?
      message = "This guild currently has no organizers. If you'd like to help organize, please contact <@#{contact_slack_id}> to be added as an organizer."
      slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
    else
      Rails.logger.warn "GUILDS_CONTACT_ID not set, skipping no-organizers message for guild #{guild.id}"
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Failed to post no-organizers message to #{guild.slack_channel_id}: #{e.message}"
  end

  def send_dm(guild, user, signup, converted, organizers_channel, admin_channel)
    return unless user.slack_id.present?

    dm_response = slack_client.conversations_open(users: user.slack_id)
    dm_channel = dm_response["channel"]["id"]

    dm_text = if converted
      "You signed up as an organizer for the Build Guild in #{guild.city}, but the maximum number of organizers has already been reached. You'll still be added to the guild channel and can participate! If you'd like to help organize, please contact an existing organizer."
    elsif signup.organizer?
      "You've signed up to organize a Build Guild in #{guild.city}! We've created a channel <##{guild.slack_channel_id}> for planning and communication with attendees. You've also been added to the central organizers channel <##{organizers_channel}> where you can talk with other organizers and ask any questions you might have about running your guild!"
    else
      "You've signed up to attend the Build Guild in #{guild.city}! We've added you to the channel <##{guild.slack_channel_id}> where you can talk to organizers and other attendees."
    end

    slack_client.chat_postMessage(channel: dm_channel, text: dm_text)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Failed to send DM to user #{user.id}: #{e.message}"
    notify_admin(admin_channel, "Failed to send DM to <@#{user.slack_id}> for #{guild.city} signup: #{e.message}")
  end

  def notify_admin(channel, message)
    return unless channel.present?
    slack_client.chat_postMessage(channel: channel, text: message)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Failed to notify admin channel: #{e.message}"
  end

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
  end
end
