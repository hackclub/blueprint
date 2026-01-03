class Admin::ProjectsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show ]
  before_action :require_reviewer_perms!, only: [ :index, :show ]

  def index
    @q = params[:q].to_s.strip

    projects = Project.includes(:user)
                      .where(is_deleted: false)
                      .order(created_at: :desc)

    if @q.present?
      like = "%#{@q}%"
      projects = projects.joins(:user).where(
        "projects.id::text ILIKE :q OR projects.title ILIKE :q OR users.username ILIKE :q OR users.email ILIKE :q",
        q: like
      )
    end

    @pagy, @projects = pagy(projects, items: 20)
  end

  def show
    @project = Project.find(params[:id])
    not_found unless @project
  end

  def delete
    @project = Project.find(params[:id])
    not_found unless @project

    @project.update!(is_deleted: true)
    redirect_to admin_projects_path, notice: "Project soft deleted."
  end

  def revive
    @project = Project.find(params[:id])
    not_found unless @project

    @project.update!(is_deleted: false)
    redirect_to admin_project_path(@project), notice: "Project revived."
  end

  def mark_viral
    @project = Project.find(params[:id])
    not_found unless @project

    @project.update!(viral: true)
    redirect_to admin_project_path(@project), notice: "Project marked as viral."
  end

  def unmark_viral
    @project = Project.find(params[:id])
    not_found unless @project

    @project.update!(viral: false)
    redirect_to admin_project_path(@project), notice: "Project unmarked as viral."
  end

  def toggle_unlisted
    @project = Project.find(params[:id])
    not_found unless @project

    @project.update!(unlisted: !@project.unlisted)
    status = @project.unlisted ? "unlisted" : "listed"
    redirect_to admin_project_path(@project), notice: "Project is now #{status}."
  end

  def force_fix_review_status
    @project = Project.find(params[:id])
    not_found unless @project

    result = @project.fix_review_status
    redirect_to admin_project_path(@project), notice: result
  end

  def switch_review_phase
    @project = Project.find(params[:id])
    not_found unless @project

    if @project.awaiting_idv? || @project.design_rejected? || @project.build_rejected? || @project.build_approved?
      return redirect_back fallback_location: admin_design_reviews_path, alert: "Cannot switch phase from current status."
    end

    mapping = {
      "design_pending" => "build_pending",
      "build_pending" => "design_pending",
      "design_needs_revision" => "build_needs_revision",
      "build_needs_revision" => "design_needs_revision",
      "design_approved" => "build_pending"
    }

    target = mapping[@project.review_status]
    return redirect_back fallback_location: admin_design_reviews_path, alert: "No valid phase transition." unless target

    @project.update!(review_status: target)
    redirect_back fallback_location: admin_design_reviews_path, notice: "Moved to #{target.humanize}."
  end

  private

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
