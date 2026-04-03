class GuildInvitesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_to_age, only: %i[show signup verify accept success]
  skip_before_action :redirect_adults, only: %i[show signup verify accept success]
  before_action :set_guild_from_slug

  rate_limit to: 10, within: 3.minutes, only: %i[signup verify], with: -> {
    redirect_to guild_invite_path(slug: params[:slug]), alert: "Too many attempts. Try again later."
  }

  def show
    @signup = current_user&.guild_signups&.find_by(guild: @guild)
  end

  def signup
    email = params[:email].to_s.strip.downcase
    birthday = params[:birthday]
    name = params[:name].to_s.strip
    invite_path = guild_invite_path(slug: params[:slug])

    return if check_honeypot!(invite_path, email: email, city: @guild&.city, name: name)
    return if check_ip_rate_limit!(invite_path, email: email, city: @guild&.city, name: name)

    if name.blank?
      redirect_to invite_path, alert: "Please enter your name."
      return
    end

    if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
      redirect_to invite_path, alert: "Please enter a valid email address."
      return
    end

    if disposable_email?(email)
      redirect_to invite_path, alert: "This email domain is not allowed. Please use a real email address."
      return
    end

    if birthday.blank?
      redirect_to invite_path, alert: "Please enter your birthday."
      return
    end

    unless AllowedEmail.allowed?(email)
      redirect_to guild_invite_path(slug: params[:slug]), alert: "You do not have access."
      return
    end

    otp = OneTimePassword.create!(email: email, request_ip: client_ip)
    if otp.send!
      session[:guild_invite_email] = email
      session[:guild_invite_birthday] = birthday
      session[:guild_invite_name] = name
      redirect_to guild_invite_path(slug: params[:slug], otp_sent: true)
    else
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Failed to send verification code. Please try again."
    end
  end

  def verify
    email = session[:guild_invite_email].to_s.strip.downcase
    birthday_raw = session[:guild_invite_birthday]
    name = session[:guild_invite_name]
    otp = params[:otp].to_s.strip

    return if check_ip_rate_limit!(guild_invite_path(slug: params[:slug], otp_sent: true), email: email)

    if email.blank?
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Please start by entering your email."
      return
    end

    unless OneTimePassword.valid?(otp, email, request_ip: client_ip)
      redirect_to guild_invite_path(slug: params[:slug], otp_sent: true), alert: "Invalid code. Please try again."
      return
    end

    session.delete(:guild_invite_email)
    session.delete(:guild_invite_birthday)
    session.delete(:guild_invite_name)

    referrer_id = cookies[:referrer_id]&.to_i
    user = User.find_or_create_from_email(email, referrer_id: referrer_id)
    cookies.delete(:referrer_id) if referrer_id

    # Set username from invite form if they dont have one (non-Slack signups)
    if user.username.blank? && name.present?
      user.update!(username: name.split.first)
    end

    reset_session
    session[:user_id] = user.id

    if user.birthday.nil? && birthday_raw.present?
      result = apply_birthday(user, birthday_raw)
      return if result == :redirected
    end

    create_guild_signup_for(user, name: name)
  end

  # Logged-in user accepts invite
  def accept
    return if check_honeypot!(guild_invite_path(slug: params[:slug]), email: current_user&.email, city: @guild&.city, name: current_user&.display_name, slack_id: current_user&.slack_id)
    return if check_ip_rate_limit!(guild_invite_path(slug: params[:slug]), email: current_user&.email, city: @guild&.city, name: current_user&.display_name, slack_id: current_user&.slack_id)

    unless current_user
      session[:after_login_redirect] = guild_invite_path(slug: params[:slug])
      redirect_to login_path, alert: "Sign up or log in to join this guild!"
      return
    end

    if current_user.guild_signups.exists?(guild: @guild)
      redirect_to guild_invite_path(slug: params[:slug]), alert: "You're already signed up for this guild!"
      return
    end

    if current_user.birthday.nil?
      if params[:birthday].blank?
        redirect_to guild_invite_path(slug: params[:slug]), alert: "Please enter your birthday."
        return
      end

      result = apply_birthday(current_user, params[:birthday])
      return if result == :redirected
    end

    create_guild_signup_for(current_user, name: params[:name])
  end

  def success
    @guild_signup = current_user&.guild_signups&.find_by(guild: @guild)
    unless @guild_signup
      redirect_to guild_invite_path(slug: params[:slug])
    end
  end

  private

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
      notify_admin_channel("Rate limited signup attempt from IP #{ip} (#{detail}). Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
      redirect_to redirect_path, alert: "You've made too many signup attempts. Please try again later."
      return true
    end

    false
  end

  def check_honeypot!(redirect_path, email: nil, city: nil, name: nil, slack_id: nil)
    honeypot_value = (params[:website].presence || params.dig(:guild_signup, :website)).to_s.strip
    return false if honeypot_value.blank?

    log_signup_attempt(client_ip, email: email, city: city, blocked: true, reason: "honeypot: #{honeypot_value}")
    notify_admin_channel("Honeypot triggered! Value: #{honeypot_value}, IP: #{client_ip}, Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
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
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Invalid date format."
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

  def create_guild_signup_for(user, name: nil)
    if user.guild_signups.exists?(guild: @guild)
      redirect_to guild_invite_success_path(slug: params[:slug])
      return
    end

    signup = user.guild_signups.build(
      guild: @guild,
      role: :attendee,
      name: name.presence || user.display_name,
      email: user.email,
      country: @guild.country,
      skip_slack_validation: true
    )

    if signup.save
      redirect_to guild_invite_success_path(slug: params[:slug])
    else
      redirect_to guild_invite_path(slug: params[:slug]),
        alert: signup.errors.full_messages.join(", ")
    end
  end

  def set_guild_from_slug
    slug = params[:slug]
    open_guilds = Guild.where.not(status: :closed)

    @guild = open_guilds.find_each.detect { |g| g.invite_slug == slug }

    unless @guild
      redirect_to guilds_path, alert: "No guild found for this invite link."
    end
  end
end
