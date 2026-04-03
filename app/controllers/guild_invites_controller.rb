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

  # Step 1: logged-out user submits name + email + birthday → send OTP
  def signup
    email = params[:email].to_s.strip.downcase
    birthday = params[:birthday]
    name = params[:name].to_s.strip

    if name.blank?
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Please enter your name."
      return
    end

    if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Please enter a valid email address."
      return
    end

    if birthday.blank?
      redirect_to guild_invite_path(slug: params[:slug]), alert: "Please enter your birthday."
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

  # Step 2: logged-out user submits OTP → verify, create account, set age, join guild
  def verify
    email = session[:guild_invite_email].to_s.strip.downcase
    birthday_raw = session[:guild_invite_birthday]
    name = session[:guild_invite_name]
    otp = params[:otp].to_s.strip

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
