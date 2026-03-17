class SlackCommandsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [ :handle ]
  before_action :verify_slack_request

  ADMIN_COMMANDS = %w[
    /guild-approve
    /guild-delete
    /guild-merge
    /guild-change-role
    /guild-status
    /guild-list
    /guild-no-organizers
  ].freeze

  def handle
    Rails.logger.info "[SlackBot] command=#{params[:command].inspect} user=#{params[:user_id]} channel=#{params[:channel_id]} text=#{params[:text].inspect}"

    if ADMIN_COMMANDS.include?(params[:command]) && !admin_channel? && !admin_user?
      Rails.logger.warn "[SlackBot] Blocked admin command #{params[:command]} from user=#{params[:user_id]} channel=#{params[:channel_id]}"
      render json: { response_type: "ephemeral", text: "This command can only be used in the admin channel." }
      return
    end

    result = case params[:command]
    when "/guild-stats"
      { response_type: "ephemeral", text: guild_stats_message }
    when "/guild-no-organizers"
      { response_type: "ephemeral", text: guilds_without_organizers_message }
    when "/guild-top"
      { response_type: "ephemeral", text: guilds_top_message(parse_limit(params[:text])) }
    when "/guild-status"
      { response_type: "ephemeral", text: guild_status_message(params[:text]) }
    when "/guild-approve"
      { response_type: "in_channel", text: guild_approve_message(params[:text]) }
    when "/guild-delete"
      { response_type: "in_channel", text: guild_delete_message(params[:text]) }
    when "/guild-merge"
      { response_type: "in_channel", text: guild_merge_message(params[:text]) }
    when "/guild-change-role"
      { response_type: "in_channel", text: guild_change_role_message(params[:text]) }
    when "/guild-list"
      { response_type: "ephemeral", text: guild_list_message }
    else
      Rails.logger.warn "[SlackBot] Unknown command: #{params[:command].inspect}"
      { response_type: "ephemeral", text: "Unknown command." }
    end

    # Log all admin command results to the admin channel
    if ADMIN_COMMANDS.include?(params[:command])
      notify_admin_channel(":hammer_and_wrench: <@#{params[:user_id]}> ran `#{params[:command]} #{params[:text]}`:\n#{result[:text]}")
    end

    render json: result
  end

  private

  def admin_channel?
    params[:channel_id] == ENV["GUILDS_ADMIN_CHANNEL"]
  end

  def admin_user?
    params[:user_id] == "U08350QEPM1"
  end

  def parse_limit(input)
    input.to_i > 0 ? input.to_i : 10
  end


  def guild_stats_message
    total_guilds = Guild.count
    total_organizers = GuildSignup.where(role: :organizer).count
    total_attendees = GuildSignup.where(role: :attendee).count
    total_signups = GuildSignup.count
    needs_review = Guild.where(needs_review: true).count

    <<~MSG
      *Guild Stats*
      • Total guilds: #{total_guilds} (#{needs_review} need review)
      • Total organizers: #{total_organizers}
      • Total attendees: #{total_attendees}
      • Total signups: #{total_signups}
    MSG
  end

  def guilds_without_organizers_message
    guilds = Guild.where.not(id: GuildSignup.where(role: :organizer).select(:guild_id))

    if guilds.any?
      list = guilds.map do |g|
        days = g.pending? ? " – pending #{g.days_pending.round} day#{'s' if g.days_pending.round != 1}" : ""
        "• #{g.name} (#{g.city})#{days}"
      end.join("\n")
      "#{guilds.count} guild#{'s' if guilds.count != 1} with no organizers:\n#{list}"
    else
      "All guilds have at least one organizer!"
    end
  end

  def guilds_top_message(limit)
    guilds = Guild.left_joins(:guild_signups)
                  .select("guilds.*, COUNT(guild_signups.id) as signups_count")
                  .group("guilds.id")
                  .order("signups_count DESC")
                  .limit(limit)

    if guilds.any?
      list = guilds.map.with_index(1) do |g, i|
        "#{i}. #{g.name} – #{g.signups_count} signup#{'s' unless g.signups_count == 1}"
      end.join("\n")
      "Top #{limit} guild#{'s' unless limit == 1} by total signups:\n#{list}"
    else
      "No guilds found."
    end
  end

  def guild_list_message
    guilds = Guild.includes(:guild_signups).order(:city)

    if guilds.any?
      list = guilds.map do |g|
        organizers = g.guild_signups.count { |s| s.organizer? }
        attendees = g.guild_signups.count { |s| s.attendee? }
        flags = []
        flags << "needs review" if g.needs_review?
        flags << "no organizers" if organizers == 0
        flag_text = flags.any? ? " :warning: #{flags.join(', ')}" : ""
        "• *#{g.name}* (#{g.city}) – #{g.status} – #{organizers} org / #{attendees} att#{flag_text}"
      end.join("\n")
      "#{guilds.count} guilds:\n#{list}"
    else
      "No guilds found."
    end
  end

  def guild_status_message(text)
    city = text.to_s.strip
    return "Usage: `/guild-status <city>`" if city.blank?

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild

    organizers = guild.guild_signups.where(role: :organizer).includes(:user)
    attendees = guild.guild_signups.where(role: :attendee).includes(:user)

    org_list = if organizers.any?
      organizers.map { |s| "  • #{s.name} (#{s.email})" }.join("\n")
    else
      "  (none)"
    end

    att_list = if attendees.any?
      attendees.map { |s| "  • #{s.name} (#{s.email})" }.join("\n")
    else
      "  (none)"
    end

    channel_text = guild.slack_channel_id.present? ? "<##{guild.slack_channel_id}>" : "(no channel)"

    <<~MSG
      *#{guild.name}* (#{guild.city}, #{guild.country})
      Status: #{guild.status} | Channel: #{channel_text} | Needs review: #{guild.needs_review? ? 'yes' : 'no'}
      Coordinates: #{guild.latitude || '?'}, #{guild.longitude || '?'}

      *Organizers (#{organizers.count}):*
      #{org_list}

      *Attendees (#{attendees.count}):*
      #{att_list}
    MSG
  end


  def guild_approve_message(text)
    city = text.to_s.strip
    return "Usage: `/guild-approve <city>`" if city.blank?

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild

    Rails.logger.info "[SlackBot] /guild-approve guild_id=#{guild.id} city=#{guild.city} signups=#{guild.guild_signups.count} by user=#{params[:user_id]}"

    guild.update!(needs_review: false) if guild.needs_review?

    guild.guild_signups.find_each do |signup|
      ProcessGuildSignupJob.perform_later(signup.id)
    end

    "Approved *#{guild.name}*. Processing #{guild.guild_signups.count} signup(s) now."
  end

  def guild_delete_message(text)
    city = text.to_s.strip
    return "Usage: `/guild-delete <city>`" if city.blank?

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild
    return "#{guild.name} is already closed." if guild.closed?

    guild_name = guild.name
    had_channel = guild.slack_channel_id.present?

    Rails.logger.info "[SlackBot] /guild-delete guild_id=#{guild.id} city=#{guild.city} had_channel=#{had_channel} by user=#{params[:user_id]}"

    # Archive the Slack channel if one exists
    if had_channel
      begin
        slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
        slack_client.conversations_archive(channel: guild.slack_channel_id)
        Rails.logger.info "[SlackBot] Archived Slack channel #{guild.slack_channel_id} for guild #{guild.id}"
      rescue => e
        Rails.logger.error "[SlackBot] Failed to archive channel for #{guild_name}: #{e.message}"
      end
    end

    guild.update!(status: :closed)

    "Closed *#{guild_name}*.#{had_channel ? ' Channel archived.' : ''}"
  end

  def guild_merge_message(text)
    cities = text.to_s.split(">>").map(&:strip)
    return "Usage: `/guild-merge <source city> >> <target city>`" unless cities.length == 2

    source = find_guild(cities[0])
    target = find_guild(cities[1])

    return "No guild found for \"#{cities[0]}\"." unless source
    return "No guild found for \"#{cities[1]}\"." unless target
    return "Cannot merge a guild into itself." if source.id == target.id

    Rails.logger.info "[SlackBot] /guild-merge source_id=#{source.id} (#{source.city}) -> target_id=#{target.id} (#{target.city}) by user=#{params[:user_id]}"

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
    Rails.logger.info "[SlackBot] Merge complete: moved=#{moved} skipped=#{skipped} source_id=#{source.id} target_id=#{target.id}"

    # Invite moved users to the target guild's Slack channel
    invite_failures = 0
    if target.slack_channel_id.present? && moved_user_ids.any?
      slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
      User.where(id: moved_user_ids).where.not(slack_id: [nil, ""]).each do |user|
        begin
          slack_client.conversations_invite(channel: target.slack_channel_id, users: user.slack_id)
          Rails.logger.info "[SlackBot] Invited user=#{user.id} (slack=#{user.slack_id}) to channel=#{target.slack_channel_id}"
        rescue Slack::Web::Api::Errors::AlreadyInChannel
          Rails.logger.info "[SlackBot] User=#{user.id} already in channel=#{target.slack_channel_id}"
        rescue Slack::Web::Api::Errors::SlackError => e
          Rails.logger.error "[SlackBot] Failed to invite user=#{user.id} to merged channel=#{target.slack_channel_id}: #{e.message}"
          invite_failures += 1
        end
      end
    end

    result = "Merged *#{source.name}* into *#{target.name}*. Moved #{moved} signup(s), removed #{skipped} duplicate(s). Source guild marked as closed."
    result += " #{invite_failures} user(s) could not be invited to <##{target.slack_channel_id}>." if invite_failures > 0
    result
  end

  def guild_change_role_message(text)
    parts = text.to_s.split
    return "Usage: `/guild-change-role @user <organizer|attendee>`" unless parts.length == 2

    raw_input = parts[0].strip
    new_role = parts[1].strip.downcase

    unless %w[organizer attendee].include?(new_role)
      return "Role must be `organizer` or `attendee`."
    end

    user = find_slack_user(raw_input)
    return "No user found for \"#{raw_input}\". Try using their Slack ID (e.g. U12345678)." unless user

    signups = user.guild_signups
    return "No guild signups found for <@#{user.slack_id}>." if signups.empty?

    results = signups.map { |s| change_signup_role(s, new_role) }
    results.join("\n")
  end

  def change_signup_role(signup, new_role)
    guild = signup.guild
    old_role = signup.role

    if old_role == new_role
      return "#{signup.name} is already #{new_role} for #{guild.city}."
    end

    if new_role == "organizer"
      existing = guild.guild_signups.where(role: :organizer).count
      if existing >= ProcessGuildSignupJob::MAX_ORGANIZERS
        Rails.logger.warn "[SlackBot] /guild-change-role blocked: guild_id=#{guild.id} already has #{existing} organizer(s)"
        return "Cannot promote #{signup.name} — #{guild.city} already has #{existing} organizer(s) (max #{ProcessGuildSignupJob::MAX_ORGANIZERS})."
      end
    end

    Rails.logger.info "[SlackBot] /guild-change-role signup_id=#{signup.id} guild_id=#{guild.id} #{old_role} -> #{new_role} by user=#{params[:user_id]}"
    signup.update!(role: new_role)
    guild.update_slack_topic

    "Changed #{signup.name} from #{old_role} to #{new_role} for *#{guild.city}*."
  end


  def find_slack_user(input)
    # Handle Slack mention format: <@U12345678> or <@U12345678|display_name>
    slack_id = input.gsub(/\A<@/, "").gsub(/(\|.*)?>?\z/, "")
    # Strip leading @ if someone typed @username
    slack_id = slack_id.gsub(/\A@/, "")

    # Try exact Slack ID match first
    user = User.find_by(slack_id: slack_id)
    return user if user

    # Fall back to username or email lookup
    User.where("LOWER(username) = ?", slack_id.downcase).first ||
      User.with_email(slack_id).first
  end

  def find_guild(city)
    Guild.where("LOWER(city) = ?", city.downcase).first ||
      Guild.where("LOWER(name) = ?", city.downcase).first
  end

  def notify_admin_channel(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue => e
    Rails.logger.error "[SlackBot] Failed to notify admin channel: #{e.message}"
  end

  def verify_slack_request
    return true if Rails.env.development?

    signing_secret = ENV["SLACK_SIGNING_SECRET"]
    slack_signature = request.headers["X-Slack-Signature"]
    slack_timestamp = request.headers["X-Slack-Request-Timestamp"]

    if Time.at(slack_timestamp.to_i) < 5.minutes.ago
      Rails.logger.warn "[SlackBot] Rejected stale request: timestamp=#{slack_timestamp}"
      head :unauthorized and return
    end

    sig_basestring = "v0:#{slack_timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    unless ActiveSupport::SecurityUtils.secure_compare(computed_signature, slack_signature)
      Rails.logger.warn "[SlackBot] Rejected request with invalid signature"
      head :unauthorized and return
    end
  end
end
