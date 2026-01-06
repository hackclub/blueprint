class Admin::StaticPagesController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index ]
  before_action :require_reviewer_perms!, only: [ :index ]

  def index
  end

  def invalidate_privileged_sessions
    PrivilegedSessionExpiry.invalidate_all!
    redirect_to admin_root_path, notice: "All privileged sessions have been invalidated."
  end

  private

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
