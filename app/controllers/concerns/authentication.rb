# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
      before_action :set_current_user
      before_action :authenticate_user!
      before_action :ensure_allowed_user!
      helper_method :current_user, :user_logged_in?
  end

  class_methods do
    def allow_unauthenticated_access(only: nil)
      skip_before_action :authenticate_user!, only: only
    end
  end

  private

  def authenticate_user!
    unless current_user
      redirect_to main_app.root_path, alert: "You need to be logged in to see this!"
    end
  end

  def ensure_allowed_user!
    return unless current_user

    if current_user.special_perms? && current_user.privileged_session_expired?
      terminate_session
      redirect_to main_app.login_path, alert: "Your session has expired. Please log in again."
      return
    end

    return if current_user.admin?

    if current_user.is_banned?
      terminate_session
      redirect_to main_app.login_path, alert: "Your account has been suspended. Please contact support."
      return
    end

    if current_user.email.match?(/\+old\d*@/)
      terminate_session
      redirect_to main_app.login_path, alert: "There was an issue with your account. Please log in again."
      return
    end

    unless AllowedEmail.allowed?(current_user.email)
      terminate_session
      redirect_to main_app.login_path, alert: "You do not have access."
    end
  end

  def user_logged_in?
    current_user.present?
  end

  def set_current_user
    uid = session[:user_id]
    oid = session[:original_id]

    if oid
      original_user = User.find_by(id: oid)
      if original_user&.admin?
        impersonated = User.find_by(id: uid)
        if impersonated
          @current_user = impersonated
        else
          reset_session
          session[:user_id] = original_user.id
          @current_user = original_user
        end
      else
        reset_session
        session[:user_id] = original_user.id if original_user
        @current_user = original_user
      end
    else
      @current_user = User.find_by(id: uid)
    end
  end

  def current_user
    @current_user
  end

  def original_user
    @original_user ||= User.find_by(id: session[:original_id]) if session[:original_id]
  end

  def impersonating?
    session[:original_id].present?
  end

  def terminate_session
    reset_session
  end
end
