class GuildSignupsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[signup verify success]
  skip_before_action :redirect_to_age, only: %i[signup verify success]
  skip_before_action :redirect_adults, only: %i[signup verify success]
  before_action :authenticate_user!, only: %i[new create]
  rate_limit to: 5, within: 10.minutes, only: %i[create signup verify], with: -> { redirect_to guilds_path, alert: "You're signing up too fast. Please try again later." }

  def new
    @signup = GuildSignup.new
  end

  def success
    @guild = Guild.find_by(id: session[:guild_signup_success_guild_id])
    unless @guild && current_user
      redirect_to guilds_path
    end
  end

  def signup
    email = params[:guild_signup][:email].to_s.strip.downcase
    birthday = params[:guild_signup][:birthday]
    city = params.dig(:guild_signup, :city).to_s.strip
    signup_name = params.dig(:guild_signup, :name).to_s.strip

    return if check_honeypot!(guilds_path(anchor: "signup-form"), email: email, city: city, name: signup_name)
    return if check_ip_rate_limit!(guilds_path(anchor: "signup-form"), email: email, city: city, name: signup_name)

    if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
      redirect_to guilds_path(anchor: "signup-form"), alert: "Please enter a valid email address."
      return
    end

    if disposable_email?(email)
      redirect_to guilds_path(anchor: "signup-form"), alert: "This email domain is not allowed. Please use a real email address."
      return
    end

    if birthday.blank?
      redirect_to guilds_path(anchor: "signup-form"), alert: "Please enter your birthday."
      return
    end

    if params.dig(:guild_signup, :role) == "organizer"
      redirect_to guilds_path(anchor: "signup-form"), alert: "You must be logged in to sign up as an organizer."
      return
    end

    unless AllowedEmail.allowed?(email)
      redirect_to guilds_path(anchor: "signup-form"), alert: "You do not have access."
      return
    end

    otp = OneTimePassword.create!(email: email, request_ip: client_ip)
    if otp.send!
      session[:guild_signup_email] = email
      session[:guild_signup_birthday] = birthday
      session[:guild_signup_data] = params[:guild_signup].permit(:role, :name, :country, :ideas, :attendee_activities, :city).to_h
      redirect_to guilds_path(otp_sent: true, anchor: "signup-form")
    else
      redirect_to guilds_path(anchor: "signup-form"), alert: "Failed to send verification code. Please try again."
    end
  end

  def verify
    email = session[:guild_signup_email].to_s.strip.downcase
    birthday_raw = session[:guild_signup_birthday]
    signup_data = session[:guild_signup_data] || {}
    otp = params[:otp].to_s.strip

    return if check_ip_rate_limit!(guilds_path(otp_sent: true, anchor: "signup-form"), email: email)

    if email.blank?
      redirect_to guilds_path(anchor: "signup-form"), alert: "Please start by entering your email."
      return
    end

    unless OneTimePassword.valid?(otp, email, request_ip: client_ip)
      redirect_to guilds_path(otp_sent: true, anchor: "signup-form"), alert: "Invalid code. Please try again."
      return
    end

    %i[guild_signup_email guild_signup_birthday guild_signup_data].each { |k| session.delete(k) }

    referrer_id = cookies[:referrer_id]&.to_i
    user = User.find_or_create_from_email(email, referrer_id: referrer_id)
    cookies.delete(:referrer_id) if referrer_id

    reset_session
    session[:user_id] = user.id

    if user.birthday.nil? && birthday_raw.present?
      result = apply_birthday(user, birthday_raw)
      return if result == :redirected
    end

    create_signup_for(user, signup_data)
  end

  def create
    raw_city = params[:guild_signup][:city]&.strip
    return if check_honeypot!(guild_signups_success_path, email: current_user&.email, city: raw_city, name: current_user&.display_name, slack_id: current_user&.slack_id)
    return if check_ip_rate_limit!(guilds_path, email: current_user&.email, city: raw_city, name: current_user&.display_name, slack_id: current_user&.slack_id)

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
      @signup.skip_slack_validation = true

      @signup.save || raise(ActiveRecord::Rollback)
    end

    if saved
      notify_admin_channel(@pending_admin_message) if @pending_admin_message.present?
      session[:guild_signup_success_guild_id] = @guild.id
      redirect_to guild_signups_success_path
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
    params.require(:guild_signup).permit(:role, :name, :email, :country, :ideas, :attendee_activities, :website)
  end

  def find_or_create_guild(raw_city, raw_country)
    country_code = ISO3166::Country.find_country_by_any_name(raw_country)&.alpha2&.downcase || raw_country&.strip

    geocoded = Geocoder.search([ raw_city, raw_country ].compact.join(", ")).first

    if geocoded.nil?
      guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                   .where("LOWER(country) = ?", country_code.downcase).first
      guild ||= find_merge_target(raw_city, country_code)
      unless guild
        begin
          guild = Guild.create!(
            city: raw_city,
            country: country_code,
            name: "#{raw_city} Guild",
            needs_review: true
          )
          @guild_is_new = true
          @pending_admin_message = "Guild '#{raw_city}' created but needs review (geocoding failed)."
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                       .where("LOWER(country) = ?", country_code.downcase).first
        end
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

      # Check if geocoder actually resolved to a city (locality), not a region/country
      raw_response = geocoded.data&.dig("raw_backend_response")
      has_locality = raw_response&.dig("results")&.any? { |r|
        r["address_components"]&.any? { |c| c["types"]&.include?("locality") }
      }
      not_a_city = raw_response.present? && !has_locality

      if geocoded.city.blank? || country_mismatch || city_mismatch || not_a_city
        guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                     .where("LOWER(country) = ?", country_code.downcase).first
        guild ||= find_merge_target(raw_city, country_code)
        unless guild
          reason = if country_mismatch
            "country mismatch: expected #{raw_country}, got #{geocoded.country_code}"
          elsif city_mismatch
            "city mismatch: typed '#{raw_city}', geocoded to '#{geocoded.city}'"
          elsif not_a_city
            "not a city: '#{raw_city}' resolved to a region/country"
          else
            "geocoder returned no city"
          end
          begin
            guild = Guild.create!(
              city: raw_city,
              country: country_code,
              name: "#{raw_city} Guild",
              needs_review: true
            )
            @guild_is_new = true
            @pending_admin_message = "Guild '#{raw_city}' created but needs review (#{reason})."
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
            guild = Guild.open.where("LOWER(city) = ?", raw_city.downcase)
                         .where("LOWER(country) = ?", country_code.downcase).first
          end
        end
      else
        guild = Guild.open.near([ geocoded.latitude, geocoded.longitude ], 15, units: :km).first
        guild ||= Guild.open.where("LOWER(city) = ?", canonical_city.downcase)
                       .where("LOWER(country) = ?", canonical_country.downcase).first
        guild ||= find_merge_target(canonical_city, canonical_country)
        guild ||= begin
          @guild_is_new = true
          Guild.create!(
            city: canonical_city,
            country: canonical_country,
            name: "#{canonical_city} Guild",
            latitude: geocoded.latitude,
            longitude: geocoded.longitude
          )
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          @guild_is_new = false
          Guild.open.where("LOWER(city) = ?", canonical_city.downcase)
                    .where("LOWER(country) = ?", canonical_country.downcase).first
        end
      end
    end

    guild
  end

  def find_merge_target(city, country_code)
    closed = Guild.where(status: :closed)
                  .where("LOWER(city) = ?", city.downcase)
                  .where("LOWER(country) = ?", country_code.downcase)
                  .first
    return nil unless closed

    target_id = GuildSignup.where(user_id: closed.users.select(:id))
                           .joins(:guild)
                           .where.not(guild_id: closed.id)
                           .merge(Guild.open)
                           .pick(:guild_id)
    Guild.open.find_by(id: target_id)
  end

  DISPOSABLE_EMAIL_DOMAINS = %w[
    tempmail.ing aniimate.net animateany.com gettranslation.app deepask.app
    animatimg.com theeditai.com wnbaldwy.com marvetos.com mailinator.com
    guerrillamail.com guerrillamail.net guerrillamail.org guerrillamail.de
    grr.la guerrillamailblock.com tempmail.com temp-mail.org temp-mail.io
    throwaway.email throwaway.cc fakeinbox.com sharklasers.com
    guerrillamail.info spam4.me trashmail.com trashmail.me trashmail.net
    yopmail.com yopmail.fr dispostable.com maildrop.cc mailnesia.com
    tempail.com tempr.email discard.email discardmail.com discardmail.de
    emailondeck.com getnada.com nada.email burnermail.io inboxbear.com
    mailcatch.com mintemail.com mohmal.com tempinbox.com 10minutemail.com
    10minutemail.net 20minutemail.com mailtemp.net harakirimail.com
    crazymailing.com tmail.ws mailsac.com emailfake.com generator.email
    tmpmail.net tmpmail.org moakt.cc moakt.ws 1secmail.com 1secmail.net
    1secmail.org internxt.com disposableemailaddress.com
  ].freeze

  def disposable_email?(email)
    domain = email.to_s.strip.downcase.split("@").last
    return false if domain.blank?

    if DISPOSABLE_EMAIL_DOMAINS.include?(domain)
      log_signup_attempt(client_ip, email: email, blocked: true, reason: "disposable email: #{domain}")
      true
    else
      false
    end
  end

  def check_ip_rate_limit!(redirect_path, email: nil, city: nil, name: nil, slack_id: nil)
    ip = client_ip
    hourly_key = "guild_signup_ip:#{ip}:#{Time.current.strftime('%Y%m%d%H')}"
    daily_key = "guild_signup_ip:#{ip}:#{Time.current.strftime('%Y%m%d')}"

    hourly_count = Rails.cache.increment(hourly_key, 1, expires_in: 1.hour) || 1
    daily_count = Rails.cache.increment(daily_key, 1, expires_in: 24.hours) || 1

    log_signup_attempt(ip, email: email, city: city, blocked: hourly_count > 2 || daily_count > 3)

    if hourly_count > 2 || daily_count > 3
      detail = hourly_count > 2 ? "#{hourly_count} attempts this hour" : "#{daily_count} attempts today"
      notify_admin_channel(">> Rate limited signup attempt from IP #{ip} (#{detail}). Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
      redirect_to redirect_path, alert: "You've made too many signup attempts. Please try again later."
      return true
    end

    false
  end

  def check_honeypot!(redirect_path, email: nil, city: nil, name: nil, slack_id: nil)
    honeypot_value = (params[:website].presence || params.dig(:guild_signup, :website)).to_s.strip
    return false if honeypot_value.blank?

    log_signup_attempt(client_ip, email: email, city: city, blocked: true, reason: "honeypot: #{honeypot_value}")
    notify_admin_channel(">> Honeypot triggered! Value: #{honeypot_value}, IP: #{client_ip}, Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
    redirect_to redirect_path
    true
  end

  def log_signup_attempt(ip, email: nil, city: nil, blocked: false, reason: nil)
    log_key = "guild_signup_log:#{ip}"
    attempts = Rails.cache.read(log_key) || []
    attempts << { email: email, city: city, blocked: blocked, reason: reason, at: Time.current.iso8601 }
    Rails.cache.write(log_key, attempts.last(20), expires_in: 7.days)

    flagged_ips = Rails.cache.read("guild_signup_flagged_ips") || []
    unless flagged_ips.include?(ip)
      flagged_ips << ip
      Rails.cache.write("guild_signup_flagged_ips", flagged_ips, expires_in: 7.days)
    end
  end

  def notify_admin_channel(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue => e
    Rails.logger.error "Failed to notify admin channel: #{e.message}"
  end

  def apply_birthday(user, birthday_raw)
    begin
      birthday_date = Date.parse(birthday_raw.to_s)
    rescue ArgumentError
      redirect_to guilds_path(anchor: "signup-form"), alert: "Invalid date format."
      return :redirected
    end

    age = ((Time.zone.now - birthday_date.to_time) / 1.year.seconds).floor

    if age < 13
      user.update!(birthday: birthday_date, is_banned: true, ban_type: :age)
      redirect_to sorry_path, alert: "You must be at least 13 years old to use Blueprint."
      return :redirected
    end

    if age > 18
      user.update!(birthday: birthday_date)
      redirect_to adult_path
      return :redirected
    end

    user.update!(birthday: birthday_date)
    nil
  end

  def create_signup_for(user, signup_data)
    raw_city = signup_data["city"]&.strip
    raw_country = signup_data["country"]&.strip

    if raw_city.blank?
      redirect_to guilds_path(anchor: "signup-form"), alert: "City can't be blank."
      return
    end

    guild = find_or_create_guild(raw_city, raw_country)
    notify_admin_channel(@pending_admin_message) if @pending_admin_message.present?

    role = %w[organizer attendee].include?(signup_data["role"]) ? signup_data["role"] : "attendee"

    signup = user.guild_signups.build(
      guild: guild,
      role: role,
      name: signup_data["name"].presence || user.display_name,
      email: user.email,
      country: guild.country,
      ideas: signup_data["ideas"],
      attendee_activities: signup_data["attendee_activities"],
      skip_slack_validation: true,
      skip_admin_validations: true
    )

    if signup.save
      session[:guild_signup_success_guild_id] = guild.id
      redirect_to guild_signups_success_path
    else
      redirect_to guilds_path(anchor: "signup-form"), alert: signup.errors.full_messages.join(", ")
    end
  end
end
