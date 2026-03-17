class GuildSignupsController < ApplicationController
  before_action :authenticate_user!
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to guilds_path, alert: "You're signing up too fast. Please try again later." }

  def new
    @signup = GuildSignup.new
  end

  def create
    raw_city = params[:guild_signup][:city]&.strip
    if raw_city.blank?
      @signup = current_user.guild_signups.build(signup_params)
      @signup.errors.add(:city, "can't be blank")
      @guilds_page = true
      render "guilds/index", status: :unprocessable_entity and return
    end

    raw_country = params[:guild_signup][:country]&.strip

    saved = ActiveRecord::Base.transaction do
      @guild_is_new = false
      @guild = find_or_create_guild(raw_city, raw_country)

      # Normalize the signup's country to match the guild's stored format
      params[:guild_signup][:country] = @guild.country if @guild&.country.present?

      @signup = current_user.guild_signups.build(signup_params)
      @signup.guild = @guild

      @signup.save || raise(ActiveRecord::Rollback)
    end

    if saved
      notify_admin_channel(@pending_admin_message) if @pending_admin_message.present?
      redirect_to guilds_path, notice: "Thanks for signing up! We'll be in touch soon."
    else
      errors = @signup&.errors&.full_messages&.join(", ")
      guild_note = @guild_is_new ? " (new guild creation for #{raw_city} was rolled back)" : " (existing guild: #{@guild&.city})"
      notify_admin_channel("Failed signup by *#{current_user.display_name}* for *#{raw_city}*#{guild_note}: #{errors}")
      @guilds_page = true
      render "guilds/index", status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:guild_signup).permit(:role, :name, :email, :country, :ideas, :attendee_activities)
  end

  def find_or_create_guild(raw_city, raw_country)
    country_code = ISO3166::Country.find_country_by_any_name(raw_country)&.alpha2&.downcase || raw_country&.strip

    geocoded = Geocoder.search([ raw_city, raw_country ].compact.join(", ")).first

    if geocoded.nil?
      guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                   .where("LOWER(country) = ?", country_code.downcase).first
      unless guild
        guild = Guild.create!(
          city: raw_city,
          country: country_code,
          name: "#{raw_city} Guild",
          needs_review: true
        )
        @guild_is_new = true
        @pending_admin_message = "Guild '#{raw_city}' created but needs review (geocoding failed)."
      end
    else
      canonical_city = geocoded.city || raw_city
      canonical_country = (geocoded.country_code || country_code)&.downcase

      geocoded_country_code = geocoded.country_code&.downcase
      country_mismatch = country_code.present? && geocoded_country_code.present? &&
                         geocoded_country_code != country_code
      normalize = ->(s) { s.downcase.gsub(/[\-\.\'\,]/, " ").gsub(/\s+/, " ").strip }
      city_mismatch = geocoded.city.present? &&
                      !normalize.call(geocoded.city).include?(normalize.call(raw_city)) &&
                      !normalize.call(raw_city).include?(normalize.call(geocoded.city))

      if geocoded.city.blank? || country_mismatch || city_mismatch
        guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                     .where("LOWER(country) = ?", country_code.downcase).first
        unless guild
          reason = if country_mismatch
            "country mismatch: expected #{raw_country}, got #{geocoded.country_code}"
          elsif city_mismatch
            "city mismatch: typed '#{raw_city}', geocoded to '#{geocoded.city}'"
          else
            "geocoder returned no city"
          end
          guild = Guild.create!(
            city: raw_city,
            country: country_code,
            name: "#{raw_city} Guild",
            needs_review: true
          )
          @guild_is_new = true
          @pending_admin_message = "Guild '#{raw_city}' created but needs review (#{reason})."
        end
      else
        guild = Guild.open.near([ geocoded.latitude, geocoded.longitude ], 10, units: :km).first
        guild ||= Guild.open.where("LOWER(city) = ?", canonical_city.downcase)
                       .where("LOWER(country) = ?", canonical_country.downcase).first
        guild ||= begin
          @guild_is_new = true
          Guild.create!(
            city: canonical_city,
            country: canonical_country,
            name: "#{canonical_city} Guild",
            latitude: geocoded.latitude,
            longitude: geocoded.longitude
          )
        end
      end
    end

    guild
  end

  def notify_admin_channel(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue => e
    Rails.logger.error "Failed to notify admin channel: #{e.message}"
  end
end
