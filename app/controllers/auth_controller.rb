class AuthController < ApplicationController
  allow_unauthenticated_access only: %i[ index new create create_email track submit_age new_hca create_hca ]
  rate_limit to: 10, within: 3.minutes, only: %i[create create_hca], with: -> { redirect_to login_path, alert: "Try again later." }
  skip_forgery_protection only: %i[ track ]
  skip_before_action :redirect_to_age, only: %i[ age submit_age destroy ]
  skip_before_action :redirect_adults, only: %i[ destroy ]

  layout false

  before_action :set_after_login_redirect, only: %i[ index new create_email new_hca ]
  before_action :redirect_if_logged_in, only: %i[ index new create create_email new_hca create_hca ]

  def index
    render "auth/index", layout: false
  end

  # Slack auth start
  def new
    if user_logged_in?
      redirect_to(post_login_redirect_path || home_path)
      return
    end

    ahoy.track "slack_login_start"

    state = SecureRandom.hex(24)
    session[:state] = state

    params = {
      client_id: ENV.fetch("SLACK_CLIENT_ID", nil),
      redirect_uri: slack_callback_url,
      state: state,
      user_scope: "identity.basic,identity.email,identity.team,identity.avatar",
      team: "T0266FRGM"
    }
    redirect_to "https://slack.com/oauth/v2/authorize?#{params.to_query}", allow_other_host: true
  end

  # email login
  def create_email
    email = params[:email]
    otp = params[:otp]

    if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = "Invalid email address."
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "flash",
              partial: "shared/notice"
            )
          ]
        end
      end
      return
    end

    if otp.present?
      unless AllowedEmail.allowed?(email)
        flash.now[:alert] = "You do not have access."
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                "flash",
                partial: "shared/notice"
              )
            ]
          end
        end
        return
      end

      if validate_otp(email, otp)
        referrer_id = cookies[:referrer_id]&.to_i
        user = User.find_or_create_from_email(email, referrer_id: referrer_id)
        ahoy.track("email_login", user_id: user&.id)
        reset_session
        session[:user_id] = user.id

        # Clear the referrer cookie after successful signup
        cookies.delete(:referrer_id) if referrer_id

        Rails.logger.info("OTP validated for email: #{email}")
        redirect_target = post_login_redirect_path
        redirect_to(redirect_target || home_path)
      else
        flash.now[:alert] = "Invalid OTP. Please try again."
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                "flash",
                partial: "shared/notice"
              )
            ]
          end
        end
      end
      return
    end

    unless AllowedEmail.allowed?(email)
      flash.now[:alert] = "You do not have access."
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "flash",
              partial: "shared/notice",
            ),
            turbo_stream.replace(
              "login_form",
              partial: "auth/email_form"
            )
          ]
        end
      end
      return
    end

    if send_otp(email)
      ahoy.track "email_login_start"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "login_form",
            partial: "auth/otp_form",
            locals: { email: email }
          )
        end
      end
    else
      flash.now[:alert] = "Failed to send OTP. Please try again."
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "flash",
              partial: "shared/notice",
            ),
            turbo_stream.replace(
              "login_form",
              partial: "auth/email_form"
            )
          ]
        end
      end
    end
  end

  # Slack auth callback
  def create
    if params[:state] != session[:state]
      Rails.logger.tagged("Authentication") do
        Rails.logger.error({
          event: "csrf_validation_failed",
          expected_state: session[:state],
          received_state: params[:state]
        }.to_json)
      end
      session[:state] = nil
      redirect_to login_path, alert: "Authentication failed due to CSRF token mismatch"
      return
    end

    begin
      referrer_id = cookies[:referrer_id]&.to_i
      user = User.exchange_slack_token(params[:code], slack_callback_url, referrer_id: referrer_id)
      user.refresh_profile! if user
      ahoy.track("slack_login", user_id: user&.id)
      reset_session
      session[:user_id] = user.id

      # Clear the referrer cookie after successful signup
      cookies.delete(:referrer_id) if referrer_id

      Rails.logger.tagged("Authentication") do
        Rails.logger.info({
          event: "authentication_successful",
          user_id: user.id,
          slack_id: user.slack_id
        }.to_json)
      end

      redirect_to(post_login_redirect_path || home_path, notice: "Welcome, #{user.display_name}!")
    rescue StandardError => e
      Rails.logger.tagged("Authentication") do
        Rails.logger.error({
          event: "authentication_failed",
          error: e.message
        }.to_json)
      end
      redirect_to login_path, alert: e.message
    end
  end

  # HCA (Hack Club Auth) login start
  def new_hca
    if user_logged_in?
      redirect_to(post_login_redirect_path || home_path)
      return
    end

    ahoy.track "hca_login_start"

    state = SecureRandom.hex(24)
    session[:hca_state] = state

    redirect_to IdentityVaultService.authorize_url(hca_callback_url, nil, state: state), allow_other_host: true
  end

  # HCA (Hack Club Auth) callback
  def create_hca
    if params[:state].blank? || params[:state] != session[:hca_state]
      Rails.logger.tagged("Authentication") do
        Rails.logger.error({
          event: "hca_csrf_validation_failed",
          expected_state: session[:hca_state],
          received_state: params[:state]
        }.to_json)
      end
      session.delete(:hca_state)
      redirect_to login_path, alert: "Authentication failed. Please try again."
      return
    end

    session.delete(:hca_state)

    begin
      referrer_id = cookies[:referrer_id]&.to_i

      code_response = IdentityVaultService.exchange_token(hca_callback_url, params[:code])
      access_token = code_response[:access_token]

      idv_data = IdentityVaultService.me(access_token)
      identity = idv_data[:identity] || {}

      email = identity[:primary_email].to_s.strip.downcase

      if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
        raise StandardError, "Your HCA account does not have a valid email address."
      end

      unless AllowedEmail.allowed?(email)
        raise StandardError, "You do not have access."
      end

      user = User.find_or_create_from_email(email, referrer_id: referrer_id)

      identity_vault_id = identity.dig(:id)
      if identity_vault_id && User.where.not(id: user.id).exists?(identity_vault_id: identity_vault_id)
        raise StandardError, "Another user already has this identity linked (share this with support: #{identity_vault_id})."
      end

      if user.identity_vault_id.present? && identity_vault_id.present? && user.identity_vault_id != identity_vault_id
        raise StandardError, "This HCA account does not match the identity already linked to your Blueprint account. Contact #blueprint-support."
      end

      addresses = identity[:addresses] || []
      primary_address = addresses.find { |a| a[:primary] } || addresses.first || {}
      has_address = addresses.any?

      user.update!(
        identity_vault_access_token: access_token,
        identity_vault_id: identity_vault_id,
        ysws_verified: identity[:verification_status] == "verified" && identity[:ysws_eligible] && has_address,
        idv_country: primary_address[:country]
      )

      ahoy.track("hca_login", user_id: user.id)

      reset_session
      session[:user_id] = user.id

      cookies.delete(:referrer_id) if referrer_id

      Rails.logger.tagged("Authentication") do
        Rails.logger.info({
          event: "hca_authentication_successful",
          user_id: user.id,
          identity_vault_id: user.identity_vault_id
        }.to_json)
      end

      redirect_to(post_login_redirect_path || home_path, notice: "Welcome, #{user.display_name}!")
    rescue StandardError => e
      Sentry.capture_exception(e)
      Rails.logger.tagged("Authentication") do
        Rails.logger.error({
          event: "hca_authentication_failed",
          error: e.message
        }.to_json)
      end
      redirect_to login_path, alert: e.message
    end
  end

  # GitHub auth start
  def github
    state = SecureRandom.hex(16)
    session[:github_state] = state
    redirect_to "https://github.com/apps/blueprint-hackclub/installations/new?state=#{state}", allow_other_host: true
  end

  # GitHub auth callback
  def create_github
    begin
      if !user_logged_in?
        redirect_to root_path, alert: "You must be logged in to link your GitHub account."
        return
      end

      # if session[:github_state].blank? || session[:github_state] != params[:state]
      #   redirect_to Flipper.enabled?(:new_flow, current_user) ? new_project_path : home_path, alert: "Invalid GitHub linking session. Please try again."
      #   return
      # end

      session.delete(:github_state) if Rails.env.production?
      current_user.link_github_account(params[:installation_id])

      Rails.logger.tagged("Authentication") do
        Rails.logger.info({
          event: "github_authentication_successful",
          user_id: current_user.id,
          github_login: current_user.github_username
        }.to_json)
      end

      redirect_to(Flipper.enabled?(:new_flow, current_user) ? new_project_path(gh: true) : home_path, notice: "GitHub account linked to @#{current_user.github_username || 'unknown'}!")
    rescue StandardError => e
      Rails.logger.tagged("Authentication") do
        Rails.logger.error({
          event: "github_authentication_failed",
          error: e.message
        }.to_json)
      end
      redirect_to Flipper.enabled?(:new_flow, current_user) ? new_project_path : home_path, alert: e.message
    end
  end

  # Logout
  def destroy
    session.delete(:original_id) if session[:original_id]
    terminate_session

    # clear Ahoy cookies
    cookies.delete(:ahoy_visit)
    cookies.delete(:ahoy_visitor)

    redirect_to root_path, notice: "Signed out successfully. Cya!"
  end

  # POST /auth/track
  def track
    email = params[:email]

    if email.present?
      EmailTrack.create(email: email)
      head :ok
    else
      head :bad_request
    end
  end

  def idv
    render "projects/ship_idv", layout: "application"
  end

  def idv_start
    state = SecureRandom.hex(24)
    session[:idv_state] = state
    idv_link = current_user.identity_vault_oauth_link(idv_callback_url, state: state)
    redirect_to idv_link, allow_other_host: true
  end

  def idv_callback
    begin
      unless params[:state].present? && params[:state] == session[:idv_state]
        redirect_to home_path, alert: "Invalid identity verification session. Please try again."
        return
      end

      session.delete(:idv_state)
      current_user.link_identity_vault_callback(idv_callback_url, params[:code])
    rescue StandardError => e
      event_id = Sentry.capture_exception(e)
      return redirect_to home_path, alert: "Couldn't link identity: #{e.message} (ask in #blueprint-support)"
    end

    redirect_to home_path, notice: "Successfully linked your identity."
  end

  def age
    render "age", layout: false
  end

  def submit_age
    unless current_user
      redirect_to login_path, alert: "Please log in first"
      return
    end

    birthday = params[:birthday]
    if birthday.blank?
      redirect_to age_verification_path, alert: "Please enter your birthday"
      return
    end

    begin
      birthday_date = Date.parse(birthday)
    rescue ArgumentError
      redirect_to age_verification_path, alert: "Invalid date format"
      return
    end

    age = ((Time.zone.now - birthday_date.to_time) / 1.year.seconds).floor

    if age < 13
      current_user.update!(birthday: birthday_date, is_banned: true, ban_type: :age)
      redirect_to sorry_path, alert: "You must be at least 13 years old to use Blueprint"
    elsif age > 18
      current_user.update!(birthday: birthday_date)
      redirect_to home_path, notice: "Thanks! You can still refer teens to Blueprint for rewards"
    else
      current_user.update!(birthday: birthday_date)
      redirect_to home_path, notice: "Welcome to Blueprint!"
    end
  end

  private

  def redirect_if_logged_in
    return unless user_logged_in?

    redirect_to(post_login_redirect_path || home_path)
  end

  def set_after_login_redirect
    path = safe_redirect_path(params[:redirect_to])
    session[:after_login_redirect] = path if path.present?
  end

  def post_login_redirect_path
    session.delete(:after_login_redirect) || safe_redirect_path(params[:redirect_to])
  end

  def safe_redirect_path(url)
    return nil if url.blank?

    begin
      uri = URI.parse(url)
      if uri.scheme.nil? && uri.host.nil? && uri.path.present? && uri.path.start_with?("/")
        return uri.path + (uri.query.present? ? "?#{uri.query}" : "")
      end
    rescue URI::InvalidURIError
    end

    nil
  end

  def send_otp(email)
    otp = OneTimePassword.create!(email: email)
    otp.send!
  end

  def validate_otp(email, otp)
    OneTimePassword.valid?(otp, email)
  end
end
