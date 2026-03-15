class ProcessGuildSignupJob < ApplicationJob
  queue_as :default

  MAX_ORGANIZERS = 2

  def perform(signup_id)
    signup = GuildSignup.find(signup_id)
    guild = signup.guild
    user = signup.user

    if guild.needs_review?
      Rails.logger.info "Guild #{guild.id} flagged for review – skipping Slack actions for signup #{signup.id}."
      return
    end

    admin_channel = ENV["GUILDS_ADMIN_CHANNEL"]
    organizers_channel = ENV["GUILDS_ORGANIZERS_CHANNEL"]
    contact_slack_id = ENV["GUILDS_CONTACT_ID"]

    converted = false
    if signup.organizer?
      existing = guild.guild_signups
                     .where(role: :organizer)
                     .where.not(id: signup.id)
                     .count
      if existing >= MAX_ORGANIZERS
        signup.update!(role: :attendee)
        converted = true
        Rails.logger.info "Converted signup #{signup.id} to attendee (exceeded max organizers)"
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "User #{user.display_name} signed up as organizer for #{guild.city} but max organizers (#{MAX_ORGANIZERS}) exceeded. Converted to attendee."
          )
        end
      end
    end

    signup.reload

    if guild.slack_channel_id.blank?
      channel_name = "build-guild-#{guild.city.parameterize}"
      begin
        response = slack_client.conversations_create(name: channel_name)
        guild.update!(slack_channel_id: response["channel"]["id"])
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "New guild channel created: <##{guild.slack_channel_id}> for #{guild.city} (triggered by #{signup.role}: #{user.display_name})"
          )
        end
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to create Slack channel for guild #{guild.id}: #{e.message}"
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "Failed to create Slack channel for #{guild.city}: #{e.message}"
          )
        end
        return
      end
    end

    if user.slack_id.present? && guild.slack_channel_id.present?
      begin
        slack_client.conversations_invite(
          channel: guild.slack_channel_id,
          users: user.slack_id
        )
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "Invited <@#{user.slack_id}> to <##{guild.slack_channel_id}> (role: #{signup.role})"
          )
        end
      rescue Slack::Web::Api::Errors::AlreadyInChannel
        Rails.logger.info "User #{user.id} already in channel #{guild.slack_channel_id}"
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to invite user #{user.id} to channel #{guild.slack_channel_id}: #{e.message}"
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "Failed to invite <@#{user.slack_id}> to <##{guild.slack_channel_id}> (role: #{signup.role}): #{e.message}"
          )
        end
      end
    elsif user.slack_id.blank? && guild.slack_channel_id.present?
      if admin_channel.present?
        slack_client.chat_postMessage(
          channel: admin_channel,
          text: "User #{user.display_name} (email: #{user.email}) has no Slack ID – cannot invite to <##{guild.slack_channel_id}> (role: #{signup.role})"
        )
      end
    end

    if guild.slack_channel_id.present?
      guild.update_slack_topic
    end

    puts ">>> Checking active status: organizer?=#{signup.organizer?}, pending?=#{guild.pending?}, organizer_count=#{guild.guild_signups.where(role: :organizer).count}"
    if signup.organizer? && guild.pending? && guild.guild_signups.where(role: :organizer).count == 1
      guild.update(status: :active)
      Rails.logger.info "Guild #{guild.id} marked as active (first organizer signup)"
      if admin_channel.present?
        slack_client.chat_postMessage(
          channel: admin_channel,
          text: "*#{guild.name}* is now active (first organizer signed up)"
        )
      end
    end

    if signup.organizer? && user.slack_id.present? && organizers_channel.present?
      begin
        slack_client.conversations_invite(
          channel: organizers_channel,
          users: user.slack_id
        )
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "Invited <@#{user.slack_id}> to <##{organizers_channel}> (organizer for #{guild.city})"
          )
        end
      rescue Slack::Web::Api::Errors::AlreadyInChannel
        Rails.logger.info "User #{user.id} already in organizers channel"
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to invite user #{user.id} to organizers channel: #{e.message}"
        if admin_channel.present?
          slack_client.chat_postMessage(
            channel: admin_channel,
            text: "Failed to invite <@#{user.slack_id}> to <##{organizers_channel}>: #{e.message}"
          )
        end
      end
    elsif signup.organizer? && user.slack_id.blank? && admin_channel.present?
      slack_client.chat_postMessage(
        channel: admin_channel,
        text: "User #{user.display_name} (email: #{user.email}) has no Slack ID - cannot invite to organizers channel"
      )
    end

    if guild.slack_channel_id.present? && user.slack_id.present?
      begin
        if signup.organizer?
          message = "Hey <@#{user.slack_id}>! Welcome to the #{guild.city} Build Guild channel. You're signed up as an organizer!"
        else
          message = "Hey <@#{user.slack_id}>! Welcome to the #{guild.city} Build Guild channel. You're signed up as an attendee!"
        end
        slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to post welcome message to #{guild.slack_channel_id}: #{e.message}"
      end
    end

    if !signup.organizer? && guild.slack_channel_id.present? && guild.guild_signups.where(role: :organizer).count == 0
      if contact_slack_id.present?
        begin
          message = "This guild currently has no organizers. If you'd like to help organize, please contact <@#{contact_slack_id}> to be added as an organizer."
          slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
        rescue Slack::Web::Api::Errors::SlackError => e
          Rails.logger.error "Failed to post no-organizers message to #{guild.slack_channel_id}: #{e.message}"
        end
      else
        Rails.logger.warn "GUILDS_CONTACT_ID not set, skipping no-organizers message for guild #{guild.id}"
      end
    end

    if user.slack_id.present?
      begin
        dm_response = slack_client.conversations_open(users: user.slack_id)
        dm_channel = dm_response["channel"]["id"]

        if converted
          dm_text = "You signed up as an organizer for the Build Guild in #{guild.city}, but the maximum number of organizers has already been reached. You've been automatically registered as an attendee. You'll still be added to the guild channel and can participate! If you'd like to help organize, please contact an existing organizer or the guild lead."
        elsif signup.organizer?
          dm_text = "You've signed up to organize a Build Guild in #{guild.city}! We've created a channel <##{guild.slack_channel_id}> for planning and communication with attendees. You've also been added to the central organizers channel <##{organizers_channel}> where you can talk with other organizers and ask any questions you might have about running your guild!"
        else
          dm_text = "You've signed up to attend the Build Guild in #{guild.city}! We've added you to the channel <##{guild.slack_channel_id}> where you can talk to organizers and other attendees."
        end

        slack_client.chat_postMessage(channel: dm_channel, text: dm_text)
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "Failed to send DM to user #{user.id}: #{e.message}"
      end
    end

  rescue => e
    Rails.logger.error "ProcessGuildSignupJob failed: #{e.message}"
    if admin_channel.present?
      slack_client.chat_postMessage(
        channel: admin_channel,
        text: "ProcessGuildSignupJob failed for signup #{signup_id}: #{e.message}"
      )
    end
    raise
  end

  private

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
  end
end
