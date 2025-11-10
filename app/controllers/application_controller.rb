class ApplicationController < ActionController::Base
  include Authentication
  include SentryContext
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  before_action :set_paper_trail_whodunnit
  before_action :update_last_active
  before_action :redirect_banned_users
  before_action :redirect_to_age
  before_action :redirect_adults

  after_action :track_page_view

  def not_found
    raise ActionController::RoutingError.new("Not Found")
  end

  private

  def track_page_view
    ahoy.track "$view", {
      controller: params[:controller],
      action: params[:action],
      user_id: current_user&.id  # if you have user authentication
    }

    # Associate the visit with the user if not already associated
    if user_logged_in? && ahoy.visit && ahoy.visit.user_id != current_user.id
      ahoy.visit.update(user_id: current_user.id)
    end
  end

  def update_last_active
    return unless current_user
    return if current_user.last_active && current_user.last_active > 5.minutes.ago

    current_user.update_column(:last_active, Time.current)
  end

  def redirect_banned_users
    return unless user_logged_in?
    return unless current_user.is_banned

    redirect_to sorry_path
  end

  def redirect_to_age
    return unless user_logged_in?
    return unless current_user.birthday.nil?

    redirect_to age_verification_path
  end

  def redirect_adults
    return unless user_logged_in?
    return unless current_user.birthday.present?
    return unless current_user.is_adult?

    redirect_to adult_path
  end
end
