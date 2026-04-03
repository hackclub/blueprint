class SlackCommandsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [ :handle ]
  before_action :verify_slack_request

  ADMIN_COMMANDS = %w[
    /guild-approve
    /guild-delete
    /guild-merge
    /guild-change-role
    /guild-relocate
    /guild-status
    /guild-list
    /guild-no-organizers
    /guild-update-channels
    /guild-add-user
    /guild-remove-user
    /guild-set-channel
    /guild-archive-closed
    /guild-sync-poc
    /guild-spam
    /guild-audit
    /guild-verify
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
      guild_merge_async(params[:text], params[:response_url])
    when "/guild-change-role"
      { response_type: "in_channel", text: guild_change_role_message(params[:text]) }
    when "/guild-relocate"
      { response_type: "in_channel", text: guild_relocate_message(params[:text]) }
    when "/guild-list"
      { response_type: "ephemeral", text: guild_list_message }
    when "/guild-update-channels"
      { response_type: "in_channel", text: guild_update_channels_message }
    when "/guild-add-user"
      { response_type: "in_channel", text: guild_add_user_message(params[:text]) }
    when "/guild-remove-user"
      { response_type: "in_channel", text: guild_remove_user_message(params[:text]) }
    when "/guild-invite"
      { response_type: "in_channel", text: guild_invite_message(params[:text], params[:user_id], params[:channel_id]) }
    when "/guild-set-channel"
      { response_type: "in_channel", text: guild_set_channel_message(params[:text]) }
    when "/guild-archive-closed"
      guild_archive_closed_async(params[:response_url])
    when "/guild-sync-poc"
      guild_sync_poc_async(params[:response_url])


    when "/guild-spam"
      { response_type: "ephemeral", text: guild_spam_message(params[:text]) }
    when "/guild-audit"
      guild_audit_async(params[:response_url])
    when "/guild-verify"
      { response_type: "in_channel", text: guild_verify_message(params[:text]) }
    when "/guild-ideas"
      { response_type: "ephemeral", text: guild_ideas_message(params[:user_id], params[:channel_id]) }
    else
      Rails.logger.warn "[SlackBot] Unknown command: #{params[:command].inspect}"
      { response_type: "ephemeral", text: "Unknown command." }
    end

    render json: result

    # Log admin command results to the admin channel after responding to Slack
    if ADMIN_COMMANDS.include?(params[:command])
      Thread.new do
        notify_admin_channel("<@#{params[:user_id]}> ran `#{params[:command]} #{params[:text]}`:\n#{result[:text]}")
      rescue => e
        Rails.logger.error "[SlackBot] Failed to log admin command to admin channel: #{e.message}"
      end
    end
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
        days = g.pending? ? " : pending #{g.days_pending.round} day#{'s' if g.days_pending.round != 1}" : ""
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
        "#{i}. #{g.name}: #{g.signups_count} signup#{'s' unless g.signups_count == 1}"
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
        "• *#{g.name}* (#{g.city}): #{g.status}: #{organizers} org / #{attendees} att#{flag_text}"
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
      organizers.map { |s|
        slack = s.user&.slack_id.present? ? " <@#{s.user.slack_id}>" : ""
        "  • #{s.name} (#{s.email})#{slack}"
      }.join("\n")
    else
      "  (none)"
    end

    att_list = if attendees.any?
      attendees.map { |s|
        slack = s.user&.slack_id.present? ? " <@#{s.user.slack_id}>" : ""
        "  • #{s.name} (#{s.email})#{slack}"
      }.join("\n")
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

    attrs = {}
    attrs[:needs_review] = false if guild.needs_review?
    attrs[:status] = :active if guild.pending?
    guild.update!(attrs) if attrs.any?

    ProcessGuildApprovalJob.perform_later(guild.id)

    "Approved *#{guild.name}* (status: #{guild.status}). Processing #{guild.guild_signups.count} signup(s) now."
  end

  def guild_delete_message(text)
    city = text.to_s.strip
    return "Usage: `/guild-delete <city>`" if city.blank?

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild
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

    guild.update!(status: :closed, needs_review: false)

    "Closed *#{guild_name}*.#{had_channel ? ' Channel archived.' : ''}"
  end

  def guild_merge_async(text, response_url)
    cities = text.to_s.split(">>").map(&:strip)
    return { response_type: "ephemeral", text: "Usage: `/guild-merge <source city> >> <target city>`" } unless cities.length == 2

    source = find_guild(cities[0])
    target = find_guild(cities[1])

    return { response_type: "ephemeral", text: "No guild found for \"#{cities[0]}\"." } unless source
    return { response_type: "ephemeral", text: "No guild found for \"#{cities[1]}\"." } unless target
    return { response_type: "ephemeral", text: "Cannot merge a guild into itself." } if source.id == target.id

    Rails.logger.info "[SlackBot] /guild-merge source_id=#{source.id} (#{source.city}) -> target_id=#{target.id} (#{target.city}) by user=#{params[:user_id]}"

    GuildMergeJob.perform_later(source.id, target.id, response_url)

    { response_type: "in_channel", text: "Merging *#{source.name}* into *#{target.name}*…" }
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

    Rails.logger.info "[SlackBot] /guild-change-role signup_id=#{signup.id} guild_id=#{guild.id} #{old_role} -> #{new_role} by user=#{params[:user_id]}"

    # Update without callbacks to avoid synchronous Airtable sync (which would timeout Slack)
    signup.update_columns(role: GuildSignup.roles[new_role], updated_at: Time.current)

    result = "Changed #{signup.name} from #{old_role} to #{new_role} for *#{guild.city}*."

    if new_role == "organizer" && guild.pending?
      guild.update!(status: :active)
      result += " Guild is now active."
    end

    # Defer Airtable sync and Slack topic update to background
    AirtableSyncClassJob.perform_later("GuildSignup")
    AirtableSyncClassJob.perform_later("Guild")
    Thread.new do
      guild.update_slack_topic
    rescue => e
      Rails.logger.error "[SlackBot] Failed to update Slack topic for guild #{guild.id}: #{e.message}"
    end

    result
  end


  def guild_relocate_message(text)
    parts = text.to_s.split(">>").map(&:strip)
    return "Usage: `/guild-relocate <current city> >> <new city>, <new country>`" unless parts.length == 2

    guild = find_guild(parts[0])
    return "No guild found for \"#{parts[0]}\"." unless guild

    new_location = parts[1]
    geocoded = Geocoder.search(new_location).first

    if geocoded.nil?
      return "Could not geocode \"#{new_location}\". Try being more specific (e.g. `Saint-Leu, Reunion`)."
    end

    new_city = geocoded.city || new_location.split(",").first.strip
    new_country = geocoded.country_code&.downcase

    old_city = guild.city
    old_country = guild.country

    guild.update!(
      city: new_city,
      country: new_country,
      name: "#{new_city} Guild",
      latitude: geocoded.latitude,
      longitude: geocoded.longitude
    )

    # Rename Slack channel if one exists
    if guild.slack_channel_id.present?
      new_channel_name = "build-guild-#{new_city.parameterize}"
      begin
        slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
        slack_client.conversations_rename(channel: guild.slack_channel_id, name: new_channel_name)
      rescue => e
        Rails.logger.error "[SlackBot] Failed to rename channel for guild #{guild.id}: #{e.message}"
      end
    end

    guild.update_slack_topic if guild.slack_channel_id.present?

    Rails.logger.info "[SlackBot] /guild-relocate guild_id=#{guild.id} from #{old_city} (#{old_country}) to #{new_city} (#{new_country}) by user=#{params[:user_id]}"

    "Relocated *#{old_city}* to *#{new_city}* (#{new_country}). Coordinates: #{geocoded.latitude}, #{geocoded.longitude}.#{guild.slack_channel_id.present? ? " Channel renamed." : ""}"
  end

  def guild_update_channels_message
    result = Guild.update_main_channel_description
    if result[:updated]
      "Updated pinned message in <##{Guild::MAIN_CHANNEL_ID}> with #{result[:total]} guild channel(s)."
    else
      "Posted and pinned guild channel list in <##{Guild::MAIN_CHANNEL_ID}> with #{result[:total]} guild channel(s)."
    end
  rescue => e
    "Failed to update channel canvas: #{e.message}"
  end

  def guild_remove_user_message(text)
    parts = text.to_s.split
    return "Usage: `/guild-remove-user <@user or email> [more users...] <city>`\nExample: `/guild-remove-user @john London`" unless parts.length >= 2

    user_inputs = []
    city_parts = []
    parts.each do |part|
      if city_parts.empty? && (part.include?("@") || part.match?(/\AU\w{8,}\z/))
        user_inputs << part.strip
      else
        city_parts << part
      end
    end

    return "No city specified." if city_parts.empty?
    return "No users specified." if user_inputs.empty?

    city = city_parts.join(" ")
    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild

    results = user_inputs.map { |raw_input| remove_user_from_guild(raw_input, guild) }

    AirtableSyncClassJob.perform_later("GuildSignup")
    AirtableSyncClassJob.perform_later("Guild")

    results.join("\n")
  end

  def remove_user_from_guild(raw_input, guild)
    user = find_slack_user(raw_input)
    return "No user found for \"#{raw_input}\"." unless user

    signup = user.guild_signups.find_by(guild: guild)
    return "#{user.display_name} (#{raw_input}) is not signed up for *#{guild.city}*." unless signup

    role = signup.role
    signup.destroy!

    Rails.logger.info "[SlackBot] /guild-remove-user user=#{user.id} guild=#{guild.id} role=#{role} by=#{params[:user_id]}"

    if guild.slack_channel_id.present? && user.slack_id.present?
      Thread.new do
        slack = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
        slack.conversations_kick(channel: guild.slack_channel_id, user: user.slack_id)
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error "[SlackBot] Failed to remove user #{user.id} from channel #{guild.slack_channel_id}: #{e.message}"
      end
    end

    "Removed #{user.display_name} (#{role}) from *#{guild.city}*."
  end

  def guild_add_user_message(text)
    parts = text.to_s.split
    return "Usage: `/guild-add-user @user <city> <attendee|organizer> [YYYY-MM-DD]`\nExample: `/guild-add-user @john London organizer 2008-08-21`\nBirthday is optional." unless parts.length >= 3

    raw_input = parts[0].strip

    raw_date = nil
    if parts[-1].match?(/\A\d{4}-\d{1,2}-\d{1,2}\z/)
      raw_date = parts[-1].strip
      role = parts[-2].strip.downcase
      city = parts[1..-3].join(" ")
    else
      role = parts[-1].strip.downcase
      city = parts[1..-2].join(" ")
    end

    unless %w[organizer attendee].include?(role)
      return "Role must be `organizer` or `attendee`."
    end

    user = find_slack_user(raw_input)
    return "No user found for \"#{raw_input}\". Try using their Slack ID (e.g. U12345678)." unless user

    guild = find_guild(city)
    return "No guild found for \"#{city}\"." unless guild

    if raw_date.present?
      begin
        birthday = Date.iso8601(raw_date)
      rescue ArgumentError
        return "Invalid date \"#{raw_date}\". Use YYYY-MM-DD format (e.g. 2008-08-21)."
      end

      return "Date cannot be in the future." if birthday > Date.current
      return "Date seems too old. Please double-check." if birthday < 120.years.ago.to_date

      user.update!(birthday: birthday)
    end

    existing_signup = user.guild_signups.find_by(guild: guild)
    if existing_signup
      result = "<@#{user.slack_id}> is already signed up for *#{guild.city}*."
      result += " Birthday updated to #{birthday.iso8601}." if birthday
      return result
    end

    signup = user.guild_signups.build(
      guild: guild,
      role: role,
      name: user.display_name,
      email: user.email,
      country: guild.country,
      skip_slack_validation: true,
      skip_admin_validations: true
    )

    if signup.save
      result = "Added <@#{user.slack_id}> to *#{guild.city}* as #{role}."
      result += " Birthday set to #{birthday.iso8601}." if birthday
      result
    else
      "Failed to add user: #{signup.errors.full_messages.join(", ")}"
    end
  end

  def guild_invite_message(text, invoker_slack_id, channel_id)
    guild = Guild.find_by(slack_channel_id: channel_id)
    return "This command must be used in a guild channel." unless guild
    return "This guild is closed." if guild.closed?

    "Here's the invite link for *#{guild.name}*:\n#{guild.invite_url}"
  end

  def guild_set_channel_message(text)
    args = text.to_s.strip.split(/\s+/, 2)
    city = args[0]
    channel_id = args[1]

    if city.blank? || channel_id.blank?
      return "Usage: `/guild-set-channel <city> <channel_id>`\nExample: `/guild-set-channel London C0AMWJ2HNH4`"
    end

    guild = Guild.where("LOWER(city) = ?", city.downcase).first
    return "No guild found for city: #{city}" unless guild

    old_channel = guild.slack_channel_id
    guild.update!(slack_channel_id: channel_id)
    "Updated *#{guild.name}* slack channel from `#{old_channel || 'none'}` to `#{channel_id}`."
  rescue => e
    "Failed to update channel: #{e.message}"
  end

  def guild_archive_closed_async(response_url)
    guilds = Guild.where(status: :closed).where.not(slack_channel_id: [ nil, "" ])

    if guilds.none?
      return { response_type: "ephemeral", text: "No closed guilds with Slack channels found." }
    end

    GuildArchiveClosedChannelsJob.perform_later(response_url)

    { response_type: "in_channel", text: "Archiving channels for #{guilds.count} closed guild(s)…" }
  end

  def guild_sync_poc_async(response_url)
    guilds = Guild.open

    if guilds.none?
      return { response_type: "ephemeral", text: "No open guilds found." }
    end

    GuildSyncPocJob.perform_later(response_url)

    { response_type: "in_channel", text: "Syncing POC data for #{guilds.count} open guild(s)…" }
  end

  def guild_ideas_message(invoker_slack_id, channel_id)
    guild = Guild.find_by(slack_channel_id: channel_id)
    return "This command must be used in a guild channel." unless guild

    signups = guild.guild_signups.where.not(attendee_activities: [ nil, "" ])
    if signups.empty?
      return "No attendee ideas have been submitted for *#{guild.name}* yet."
    end

    list = signups.map.with_index(1) { |s, i| "#{i}. #{s.attendee_activities}" }.join("\n")
    "*Attendee ideas for #{guild.name}* (#{signups.count}):\n#{list}"
  end

  def guild_spam_message(text)
    ip = text.to_s.strip

    if ip.blank?
      flagged_ips = Rails.cache.read("guild_signup_flagged_ips") || []
      return "No flagged IPs found." if flagged_ips.empty?

      lines = flagged_ips.filter_map do |addr|
        attempts = Rails.cache.read("guild_signup_log:#{addr}") || []
        next if attempts.empty?

        blocked_count = attempts.count { |a| a[:blocked] }
        total = attempts.size
        emails = attempts.filter_map { |a| a[:email] }.uniq.first(3)
        email_preview = emails.any? ? " (#{emails.join(', ')})" : ""
        "#{addr}: #{total} attempt#{'s' unless total == 1}, #{blocked_count} blocked#{email_preview}"
      end

      return "No signup attempts logged." if lines.empty?
      "*Flagged IPs:*\n#{lines.join("\n")}"
    else
      attempts = Rails.cache.read("guild_signup_log:#{ip}") || []
      return "No signup attempts found for IP #{ip}." if attempts.empty?

      lines = attempts.map do |a|
        status = a[:blocked] ? "blocked" : "allowed"
        reason = a[:reason] ? " (#{a[:reason]})" : ""
        time = a[:at] ? Time.iso8601(a[:at]).strftime("%b %d %H:%M") : "?"
        "• #{time} #{a[:email] || 'N/A'} #{a[:city] || 'N/A'} #{status}#{reason}"
      end

      "*Signup attempts from #{ip}:*\n#{lines.join("\n")}"
    end
  end

  def guild_verify_message(text)
    parts = text.to_s.split
    return "Usage: `/guild-verify <email> [more emails...]`\nTo clear the verified list: `/guild-verify reset`" if parts.empty?

    if parts[0].downcase == "reset"
      Rails.cache.delete("guild_audit_verified_ids")
      return "Cleared all verified signups. They will appear in the next audit."
    end

    verified_ids = Rails.cache.read("guild_audit_verified_ids") || Set.new
    results = []

    parts.each do |email|
      email = email.strip.downcase
      signups = GuildSignup.where("LOWER(email) = ?", email)

      if signups.empty?
        results << "No signups found for `#{email}`."
        next
      end

      signups.each do |signup|
        verified_ids << signup.id
        results << "Verified `#{email}` for *#{signup.guild&.city || 'unknown'}*."
      end
    end

    Rails.cache.write("guild_audit_verified_ids", verified_ids)
    results.join("\n")
  end

  def guild_audit_async(response_url)
    GuildAuditJob.perform_later(response_url)
    { response_type: "in_channel", text: "Running fraud audit across all guild signups…" }
  end

  def find_slack_user(input)
    slack_id = input.gsub(/\A<@/, "").gsub(/(\|.*)?>?\z/, "")
    slack_id = slack_id.gsub(/\A@/, "")

    # Try exact Slack ID match first
    user = User.find_by(slack_id: slack_id)
    return user if user

    # Fall back to username or email lookup
    User.where("LOWER(username) = ?", slack_id.downcase).first ||
      User.with_email(slack_id).first
  end

  def find_guild(city)
    guild = Guild.where("LOWER(city) = ?", city.downcase).first ||
            Guild.where("LOWER(name) = ?", city.downcase).first
    return guild if guild

    # Fall back to accent-insensitive match
    normalized = city.unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase
    Guild.find_each do |g|
      return g if g.city&.unicode_normalize(:nfkd)&.gsub(/\p{M}/, "")&.downcase == normalized
    end
    Guild.find_each do |g|
      return g if g.name&.unicode_normalize(:nfkd)&.gsub(/\p{M}/, "")&.downcase == normalized
    end
    nil
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
