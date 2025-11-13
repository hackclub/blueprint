class Admin::DesignReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_random, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_random, :create ]

  def index
    reviewed_ids = Project.joins(:design_reviews)
                            .where(is_deleted: false, review_status: :design_pending)
                            .where(design_reviews: { invalidated: false })
                            .distinct
                            .pluck(:id)
    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .includes(:user, :journal_entries)
                        .select("projects.*, CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN true ELSE false END AS pre_reviewed")
                        .order(Arel.sql("CASE WHEN id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END, created_at ASC"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .where.not(id: reviewed_ids)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .includes(:user, :journal_entries)
                        .order(created_at: :asc)
    end

    @top_reviewers = User.joins(:design_reviews)
                         .where("design_reviews.created_at >= ?", 7.days.ago)
                         .group("users.id")
                         .select("users.*, COUNT(design_reviews.id) AS reviews_count")
                         .order("reviews_count DESC")
  end

  def show
    @project = Project.find(params[:id])
    not_found unless @project
    @design_review = @project.design_reviews.build
  end

  def show_random
    base = Project.active.design_pending
    reviewed = base.with_valid_design_review
    unreviewed = base.without_valid_design_review

    project_id =
      if current_user.admin?
        random_pick_id(reviewed) || random_pick_id(unreviewed)
      else
        random_pick_id(unreviewed.not_led)
      end

    if project_id
      redirect_to admin_design_review_path(project_id)
    else
      redirect_to admin_design_reviews_path, alert: "No projects pending review."
    end
  end

  def create
    @project = Project.find(params[:id])
    @design_review = @project.design_reviews.build(design_review_params)
    @design_review.reviewer = current_user
    @design_review.admin_review = current_user.admin?

    if @design_review.save
      if current_user.admin? && params[:design_review][:ysws].present?
        @project.update(ysws: params[:design_review][:ysws])
      end
      update_project_review_status(@project, @design_review)
      redirect_to admin_random_design_review_path, notice: "Design review submitted successfully. Showing new project."
    else
      redirect_to admin_design_review_path(@project), alert: @design_review.errors.full_messages.to_sentence
    end
  end

  private

  def random_pick_id(scope)
    scope.pluck(:id).sample
  end

  def design_review_params
    params.require(:design_review).permit(:hours_override, :reason, :grant_override_cents, :result, :feedback, :tier_override)
  end

  def update_project_review_status(project, design_review)
    case design_review.result
    when "rejected"
      project.design_reviews.where.not(id: design_review.id).update_all(invalidated: true)
      project.update!(review_status: :design_rejected)
    when "returned"
      project.design_reviews.where.not(id: design_review.id).update_all(invalidated: true)
      project.update!(review_status: :design_needs_revision)
    when "approved"
      admin_approvals = project.design_reviews.where(result: "approved", invalidated: false, admin_review: true)

      if admin_approvals.exists?
        project.update!(review_status: :design_approved)
      end
    end
  end

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
