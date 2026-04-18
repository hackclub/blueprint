class GuildsController < ApplicationController
  DISMISSIBLE_NOTICES = %w[venue_form funding_form safeguarding].freeze
  DISMISSED_COOKIE = :guild_dismissed_notices

  skip_before_action :authenticate_user!, only: [ :index, :map_data ]

  def index
    @guilds = Guild.order(:name)
    @signup = GuildSignup.new
    @city = params[:city]
  end

  def dashboard
    @user_signups = current_user.guild_signups.includes(:guild).where.not(role: :volunteer).order(role: :asc).to_a

    if params[:guild_id].present?
      @signup = @user_signups.find { |s| s.guild_id == params[:guild_id].to_i }
    end
    @signup ||= @user_signups.first

    unless @signup
      redirect_to guilds_path, alert: "You need to be signed up for a guild to access the dashboard."
      return
    end
    @is_organizer = @signup.organizer?
    @guild = @signup.guild
    @is_poc = @is_organizer && @guild.guild_signups.where(role: :organizer).order(:created_at).first&.user_id == current_user.id
    if @guild.needs_review
      redirect_to guilds_path, alert: "Your guild is currently under review. You'll get access to the dashboard once it's approved."
      return
    end
    if @guild.closed?
      redirect_to guilds_path, alert: "This guild has been closed."
      return
    end
    @signups = @guild.guild_signups.includes(:user).order(role: :asc, created_at: :desc)
    @ideas = @guild.guild_signups
      .where.not(attendee_activities: [ nil, "" ])
      .or(@guild.guild_signups.where.not(ideas: [ nil, "" ]))
      .includes(:user)
    @dismissed_notices = read_dismissed_notices_for(@guild)
    session[:guild_dashboard_last_seen] = Time.current.iso8601
  end

  def create_announcement
    signup = current_user.guild_signups.find_by(role: :organizer)
    unless signup
      redirect_to guilds_path, alert: "Only organizers can post announcements."
      return
    end
    body = params[:announcement][:body].to_s.strip
    if body.blank?
      redirect_to guild_dashboard_path, alert: "Announcement can't be blank."
      return
    end
    signup.guild.add_announcement!(body, current_user.display_name || "Organizer")
    redirect_to guild_dashboard_path, notice: "Announcement posted."
  end

  def delete_announcement
    signup = current_user.guild_signups.find_by(role: :organizer)
    unless signup
      redirect_to guilds_path, alert: "Only organizers can delete announcements."
      return
    end
    signup.guild.delete_announcement!(params[:posted_at])
    redirect_to guild_dashboard_path, notice: "Announcement deleted."
  end

  def leave_guild
    signup = current_user.guild_signups.find_by(guild_id: params[:guild_id])
    unless signup
      redirect_to guild_dashboard_path, alert: "You're not signed up for this guild."
      return
    end

    guild = signup.guild
    role = signup.role
    signup.destroy!
    notify_admin_channel("*#{current_user.display_name}* (#{current_user.email}) left *#{guild.city}* Build Guild (was #{role})")
    redirect_to guild_dashboard_path, notice: "You have left #{guild.city}."
  end

  def close_signups
    guild = organizer_guild_from_params
    return unless guild

    if guild.signups_closed?
      redirect_to guild_dashboard_path(guild_id: guild.id), notice: "Signups are already closed."
      return
    end
    guild.close_signups!
    notify_admin_channel("<@U08350QEPM1> build guild #{guild.invite_slug} has closed signups to their guild")
    notify_guild_channel(guild, "Signups for this Build Guild are now closed. Please check your email for a link to register your attendance!")
    redirect_to guild_dashboard_path(guild_id: guild.id), notice: "Signups closed. Check-in forms and waivers will be released within a few hours."
  end

  def reopen_signups
    guild = organizer_guild_from_params
    return unless guild

    unless guild.signups_closed?
      redirect_to guild_dashboard_path(guild_id: guild.id), notice: "Signups are already open."
      return
    end
    if guild.signups_closed_by_admin?
      redirect_to guild_dashboard_path(guild_id: guild.id), alert: "Signups were closed by an admin and can't be reopened from the dashboard."
      return
    end
    guild.reopen_signups!
    notify_admin_channel("<@U08350QEPM1> build guild #{guild.invite_slug} has re-enabled signups to their guild")
    redirect_to guild_dashboard_path(guild_id: guild.id), notice: "Signups reopened."
  end

  def dismiss_notice
    signup = current_user.guild_signups.find_by(guild_id: params[:guild_id])
    unless signup
      redirect_to guilds_path, alert: "You're not signed up for this guild."
      return
    end

    key = params[:key].to_s
    unless DISMISSIBLE_NOTICES.include?(key)
      redirect_to guild_dashboard_path(guild_id: signup.guild_id), alert: "Unknown notice."
      return
    end

    store = cookies.signed[DISMISSED_COOKIE]
    store = store.is_a?(Hash) ? store.deep_dup : {}
    store[signup.guild_id.to_s] ||= {}
    store[signup.guild_id.to_s][key] = Time.current.iso8601
    cookies.signed.permanent[DISMISSED_COOKIE] = { value: store, httponly: true, same_site: :lax }

    redirect_to guild_dashboard_path(guild_id: signup.guild_id)
  end

  def map_data
    @guilds = Guild.includes(:guild_signups)
                   .where.not(latitude: nil, longitude: nil)
                   .where(needs_review: [ false, nil ])
                   .where.not(status: :closed)
    render json: @guilds.map { |g|
      {
        id: g.id,
        name: g.name,
        city: g.city,
        country: g.country,
        lat: g.latitude,
        lng: g.longitude,
        signup_count: g.guild_signups.size,
        slack_channel_id: g.slack_channel_id,
        website_url: g.website_url
      }
    }
  end

  private

  def read_dismissed_notices_for(guild)
    raw = cookies.signed[DISMISSED_COOKIE]
    return {} unless raw.is_a?(Hash)
    (raw[guild.id.to_s] || {}).slice(*DISMISSIBLE_NOTICES)
  end

  def organizer_guild_from_params
    signup = current_user.guild_signups.find_by(guild_id: params[:guild_id], role: :organizer)
    unless signup
      redirect_to guilds_path, alert: "Only organizers can manage guild signups."
      return nil
    end
    signup.guild
  end

  def notify_admin_channel(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue
  end

  def notify_guild_channel(guild, message)
    return unless guild.slack_channel_id.present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: guild.slack_channel_id, text: message)
  rescue
  end
end
