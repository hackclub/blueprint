# frozen_string_literal: true

class HcbTokenRefreshJob < ApplicationJob
  queue_as :background

  def perform
    user = User.find_by(hcb_integration_enabled: true)
    return unless user

    unless user.hcb_refresh_token.present?
      Rails.logger.error("HCB integration enabled but no refresh token present for user #{user.id}")
      Sentry.capture_message("HCB integration has no refresh token", level: :error, extra: { user_id: user.id })
      return
    end

    unless user.hcb_token_expires_at.present? && user.hcb_token_expires_at < 20.minutes.from_now
      Rails.logger.info("HCB token not expiring soon, skipping refresh")
      return
    end

    user.with_lock do
      begin
        token_response = HcbOauthService.refresh_token(user.hcb_refresh_token)

        user.update!(
          hcb_access_token: token_response[:access_token],
          hcb_refresh_token: token_response[:refresh_token] || user.hcb_refresh_token,
          hcb_token_expires_at: Time.current + token_response[:expires_in].to_i.seconds
        )

        Rails.logger.info("HCB token refreshed successfully for user #{user.id}, expires at #{user.hcb_token_expires_at}")
      rescue Faraday::UnauthorizedError, Faraday::BadRequestError => e
        Rails.logger.error("HCB token refresh failed with auth error: #{e.message}")
        Sentry.capture_exception(e, level: :error, extra: {
          user_id: user.id,
          event: "hcb_token_refresh_auth_failure"
        })

        user.update!(
          hcb_integration_enabled: false,
          hcb_access_token: nil,
          hcb_refresh_token: nil,
          hcb_token_expires_at: nil
        )

        Sentry.capture_message("HCB integration disabled due to refresh failure", level: :warning, extra: { user_id: user.id })
      rescue StandardError => e
        Rails.logger.error("HCB token refresh failed unexpectedly: #{e.message}")
        Sentry.capture_exception(e, extra: {
          user_id: user.id,
          event: "hcb_token_refresh_unexpected_failure"
        })
      end
    end
  end
end
