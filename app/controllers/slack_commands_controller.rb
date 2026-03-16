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
    if ADMIN_COMMANDS.include?(params[:command]) && !admin_channel?
      render json: { response_type: "ephemeral", text: "This command can only be used in the admin channel." }
      return
    end

    case params[:command]
    when "/guild-stats"
      render json: { response_type: "ephemeral", text: guild_stats_message }
    when "/guild-no-organizers"
      render json: { response_type: "ephemeral", text: guilds_without_organizers_message }
    when "/guild-top"
      limit = parse_limit(params[:text])
      render json: { response_type: "ephemeral", text: guilds_top_message(limit) }
    when "/guild-status"
      render json: { response_type: "ephemeral", text: guild_status_message(params[:text]) }
    when "/guild-approve"
      render json: { response_type: "in_channel", text: guild_approve_message(params[:text]) }
    when "/guild-delete"
      render json: { response_type: "in_channel", text: guild_delete_message(params[:text]) }
    when "/guild-merge"
      render json: { response_type: "in_channel", text: guild_merge_message(params[:text]) }
    when "/guild-change-role"
      render json: { response_type: "in_channel", text: guild_change_role_message(params[:text]) }
    when "/guild-list"
      render json: { response_type: "ephemeral", text: guild_list_message }
    else
      render json: { response_type: "ephemeral", text: "Unknown command." }
    end
  end

  private

  def admin_channel?
    params[:channel_id] == ENV["GUILDS_ADMIN_CHANNEL"]
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
    return "#{guild.name} is not flagged for review." unless guild.needs_review?

    guild.update!(needs_review: false)

    # Process any signups that were skipped due to needs_review
    guild.guild_signups.find_each do |signup|
      ProcessGuildSignupJob.perform_later(signup.id)
    end

    "Approved *#{guild.name}*. Processing #{guild.guild_signups.count} pending signup(s) now."
  end

  def guild_delete_message(text)
    city = text.to_s.strip
    return "Usage: `/guild-delete <city>`" if city.blank?

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild
    return "#{guild.name} is already closed." if guild.closed?

    guild_name = guild.name
    had_channel = guild.slack_channel_id.present?

    # Archive the Slack channel if one exists
    if had_channel
      begin
        slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
        slack_client.conversations_archive(channel: guild.slack_channel_id)
      rescue => e
        Rails.logger.error "Failed to archive channel for #{guild_name}: #{e.message}"
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

    moved = 0
    skipped = 0
    source.guild_signups.to_a.each do |signup|
      if target.guild_signups.exists?(user_id: signup.user_id)
        signup.destroy!
        skipped += 1
      else
        signup.update!(guild_id: target.id)
        moved += 1
      end
    end

    source.update!(status: :closed)

    "Merged *#{source.name}* into *#{target.name}*. Moved #{moved} signup(s), removed #{skipped} duplicate(s). Source guild marked as closed."
  end

  def guild_change_role_message(text)
    parts = text.to_s.split
    return "Usage: `/guild-change-role @user <organizer|attendee>`" unless parts.length == 2

    slack_id = parts[0].strip.gsub(/\A<@/, "").gsub(/(\|.*)?>?\z/, "")
    new_role = parts[1].strip.downcase

    unless %w[organizer attendee].include?(new_role)
      return "Role must be `organizer` or `attendee`."
    end

    user = User.find_by(slack_id: slack_id)
    return "No user found for <@#{slack_id}>." unless user

    signups = user.guild_signups
    return "No guild signups found for <@#{slack_id}>." if signups.empty?

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
        return "Cannot promote #{signup.name} — #{guild.city} already has #{existing} organizer(s) (max #{ProcessGuildSignupJob::MAX_ORGANIZERS})."
      end
    end

    signup.update!(role: new_role)
    guild.update_slack_topic

    "Changed #{signup.name} from #{old_role} to #{new_role} for *#{guild.city}*."
  end


  def find_guild(city)
    Guild.where("LOWER(city) = ?", city.downcase).first ||
      Guild.where("LOWER(name) = ?", city.downcase).first
  end

  def verify_slack_request
    return true if Rails.env.development?

    signing_secret = ENV["SLACK_SIGNING_SECRET"]
    slack_signature = request.headers["X-Slack-Signature"]
    slack_timestamp = request.headers["X-Slack-Request-Timestamp"]

    if Time.at(slack_timestamp.to_i) < 5.minutes.ago
      head :unauthorized and return
    end

    sig_basestring = "v0:#{slack_timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    unless ActiveSupport::SecurityUtils.secure_compare(computed_signature, slack_signature)
      head :unauthorized and return
    end
  end
end
