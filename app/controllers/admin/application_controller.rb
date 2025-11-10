class Admin::ApplicationController < ApplicationController
  layout "admin"
  before_action :require_admin!
  before_action :set_paper_trail_whodunnit
  skip_before_action :redirect_banned_users
  skip_before_action :redirect_adults

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
