class GuildSignupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_guild, only: [ :create ]

  def new
    @signup = GuildSignup.new
  end

  def create
    @signup = current_user.guild_signups.build(signup_params)
    @signup.guild = @guild

    if @signup.save
      ProcessGuildSignupJob.perform_later(@signup.id)
      SendGuildEmailJob.perform_later(@signup.id)
      redirect_to guilds_path, notice: "Thanks for signing up! We'll be in touch soon."
    else
      @guilds_page = true
      render "guilds/index", status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:guild_signup).permit(:role, :name, :email, :country, :ideas, :attendee_activities)
  end

  def set_guild
    raw_city = params[:guild_signup][:city]&.strip
    raw_country = params[:guild_signup][:country]&.strip

    if raw_city.blank?
      @signup = current_user.guild_signups.build(signup_params)
      @signup.errors.add(:city, "can't be blank")
      render "guilds/index", status: :unprocessable_entity and return
    end

    geocoded = Geocoder.search([ raw_city, raw_country ].compact.join(", ")).first

    if geocoded.nil?
      @guild = Guild.create!(
        city: raw_city,
        country: raw_country,
        name: "#{raw_city} Guild",
        needs_review: true
      )
      notify_admin_channel("Guild '#{raw_city}' created but needs review (geocoding failed).")
    else
      canonical_city = geocoded.city || raw_city
      canonical_country = geocoded.country_code || raw_country

      @guild = Guild.find_or_create_by(city: canonical_city, country: canonical_country) do |g|
        g.name = "#{canonical_city} Guild"
        g.latitude = geocoded.latitude
        g.longitude = geocoded.longitude
        g.country = canonical_country
      end
    end
  end

  private

  def notify_admin_channel(message)
    return unless ENV["SLACK_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["SLACK_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["SLACK_ADMIN_CHANNEL"], text: message)
  rescue => e
    Rails.logger.error "Failed to notify admin channel: #{e.message}"
  end
end
