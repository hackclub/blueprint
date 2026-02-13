# frozen_string_literal: true

class HcbOauthController < ApplicationController
  skip_before_action :redirect_to_age
  skip_before_action :redirect_adults

  def start
    state = SecureRandom.hex(24)
    session[:hcb_oauth_state] = state

    ahoy.track "hcb_oauth_start"

    redirect_to HcbOauthService.authorize_url(hcb_callback_url, state:), allow_other_host: true
  end

  def callback
    unless params[:state].present? && params[:state] == session[:hcb_oauth_state]
      Rails.logger.tagged("HcbOauth") do
        Rails.logger.error({
          event: "csrf_validation_failed",
          expected_state: session[:hcb_oauth_state].present? ? "[PRESENT]" : "[MISSING]",
          received_state: params[:state].present? ? "[PRESENT]" : "[MISSING]"
        }.to_json)
      end
      session.delete(:hcb_oauth_state)
      redirect_to admin_root_path, alert: "HCB OAuth failed: invalid state parameter"
      return
    end

    session.delete(:hcb_oauth_state)

    if params[:error].present?
      Rails.logger.tagged("HcbOauth") do
        Rails.logger.error({
          event: "oauth_error",
          error: params[:error],
          error_description: params[:error_description]
        }.to_json)
      end
      redirect_to admin_root_path, alert: "HCB OAuth denied: #{params[:error_description] || params[:error]}"
      return
    end

    begin
      token_response = HcbOauthService.exchange_token(hcb_callback_url, params[:code])

      current_user.update!(
        hcb_access_token: token_response[:access_token],
        hcb_refresh_token: token_response[:refresh_token],
        hcb_token_expires_at: Time.current + token_response[:expires_in].to_i.seconds
      )

      ahoy.track "hcb_oauth_success"

      Rails.logger.tagged("HcbOauth") do
        Rails.logger.info({
          event: "oauth_success",
          user_id: current_user.id,
          expires_at: current_user.hcb_token_expires_at
        }.to_json)
      end

      redirect_to admin_root_path, notice: "HCB integration connected successfully!"
    rescue Faraday::BadRequestError, Faraday::UnauthorizedError => e
      Sentry.capture_exception(e)
      Rails.logger.tagged("HcbOauth") do
        Rails.logger.error({
          event: "token_exchange_failed",
          error: e.message
        }.to_json)
      end
      redirect_to admin_root_path, alert: "HCB OAuth failed: could not exchange authorization code"
    rescue StandardError => e
      Sentry.capture_exception(e)
      Rails.logger.tagged("HcbOauth") do
        Rails.logger.error({
          event: "oauth_unexpected_error",
          error: e.message
        }.to_json)
      end
      redirect_to admin_root_path, alert: "HCB OAuth failed unexpectedly"
    end
  end

  def disconnect
    current_user.update!(
      hcb_integration_enabled: false,
      hcb_access_token: nil,
      hcb_refresh_token: nil,
      hcb_token_expires_at: nil
    )

    ahoy.track "hcb_oauth_disconnect"

    redirect_to admin_root_path, notice: "HCB integration disconnected"
  end
end
