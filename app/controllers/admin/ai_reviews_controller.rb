class Admin::AiReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!
  before_action :require_reviewer_perms!

  def create
    project = Project.find(params[:project_id])
    phase = params[:review_phase]

    unless %w[design build].include?(phase)
      redirect_back fallback_location: admin_root_path, alert: "Invalid review phase."
      return
    end

    AiReviewJob.perform_later(project.id, phase)
    redirect_back fallback_location: admin_root_path, notice: "AI analysis queued. Check back in ~5 minutes."
  end

  private

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
