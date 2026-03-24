class GuildsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :map_data ]

  def index
    @guilds = Guild.order(:name)
    @signup = GuildSignup.new
    @city = params[:city]
  end

  def dashboard
    @signup = current_user.guild_signups.order(role: :asc).first # organizer (0) before attendee (1)
    unless @signup
      redirect_to guilds_path, alert: "You need to be signed up for a guild to access the dashboard."
      return
    end
    @is_organizer = @signup.organizer?
    @guild = @signup.guild
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

  def map_data
    @guilds = Guild.includes(:guild_signups)
                   .where.not(latitude: nil, longitude: nil)
                   .where(needs_review: [false, nil])
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
end
