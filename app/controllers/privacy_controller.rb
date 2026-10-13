class PrivacyController < ActionController::API
  rescue_from(StandardError) { |error| render_error :internal_error, :internal_server_error, error_class: error.class.name }
  rescue_from(PrivacyToken::Invalid) { render_error :invalid_token, :unauthorized }
  rescue_from(PrivacyToken::ActionMismatch) { render_error :action_mismatch, :bad_request }
  rescue_from(PrivacyToken::Replayed) { render_error :replayed, :conflict }
  rescue_from(PrivacyToken::Unavailable) { render_error :jwks_unavailable, :service_unavailable }
  rescue_from(PrivacyDeletion::ManualReviewRequired) { render_error :manual_review_required, :conflict }
  rescue_from(PrivacyDeletion::ExternalFailure) { render_error :storage_unavailable, :service_unavailable }

  around_action :without_sentry_events
  before_action :verify_token!

  def delete
    raise PrivacyToken::Invalid unless [ true, false ].include?(@payload["dry_run"])

    render_result PrivacyDeletion.new(@payload["subject"], dry_run: @payload["dry_run"]).call
  end

  def export
    render_result PrivacyDeletion.new(@payload["subject"], dry_run: true).call
  end

  private

  # Sentry sends request headers and SQL breadcrumbs, which would include the token and the subject's emails.
  def without_sentry_events
    Sentry.with_scope do |scope|
      scope&.add_event_processor { nil }
      yield
    end
  end

  def verify_token!
    token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    @payload = PrivacyToken.verify!(token, action: action_name)
  end

  def render_result(result)
    log_outcome(result.found? ? "found" : "not_found")
    render json: {
      request_id: @payload["request_id"],
      found: result.found?,
      dry_run: @payload["dry_run"],
      deleted: result.deleted,
      retained: result.retained
    }
  end

  def render_error(code, status, **details)
    log_outcome(code, **details)
    render json: { error: code }, status: status
  end

  def log_outcome(outcome, **details)
    Rails.logger.tagged("PrivacyRequest") do
      Rails.logger.info({ event: "privacy_request", request_id: @payload&.dig("request_id"), action: action_name, outcome: outcome, **details }.to_json)
    end
  end
end
