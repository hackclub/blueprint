class Admin::BuildReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_random, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_random, :create ]

  def index
    # Only consider non-approved reviews to allow resubmitted projects to be visible
    reviewed_ids = Project.joins(:build_reviews)
                            .where(is_deleted: false, review_status: :build_pending)
                            .where(build_reviews: { invalidated: false })
                            .where.not(build_reviews: { result: BuildReview.results[:approved] })
                            .distinct
                            .pluck(:id)
    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .includes(:user, :journal_entries)
                        .select("projects.*, CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN true ELSE false END AS pre_reviewed")
                        .order(Arel.sql("CASE WHEN id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END, created_at ASC"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .where.not(id: reviewed_ids)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .includes(:user, :journal_entries)
                        .order(created_at: :asc)
    end

    @top_reviewers = User.joins(:build_reviews)
                         .where("build_reviews.created_at >= ?", 7.days.ago)
                         .group("users.id")
                         .select("users.*, COUNT(build_reviews.id) AS reviews_count")
                         .order("reviews_count DESC")
  end

  def show
    @project = Project.find(params[:id])
    not_found unless @project
    @build_review = @project.build_reviews.build
  end

  def show_random
    base = Project.active.build_pending
    reviewed = base.with_valid_build_review
    unreviewed = base.without_valid_build_review

    project_id =
      if current_user.admin?
        random_pick_id(reviewed) || random_pick_id(unreviewed)
      else
        random_pick_id(unreviewed.not_led)
      end

    if project_id
      redirect_to admin_build_review_path(project_id)
    else
      redirect_to admin_build_reviews_path, alert: "No projects pending review."
    end
  end

  def create
    @project = Project.find(params[:id])
    @build_review = @project.build_reviews.build(build_review_params)
    @build_review.reviewer = current_user
    @build_review.admin_review = current_user.admin?

    if @build_review.save
      update_project_review_status(@project, @build_review)
      redirect_to admin_random_build_review_path, notice: "Build review submitted successfully. Showing new project."
    else
      redirect_to admin_build_review_path(@project), alert: @build_review.errors.full_messages.to_sentence
    end
  end

  private

  def random_pick_id(scope)
    scope.reorder(Arel.sql("RANDOM()")).limit(1).pick(:id)
  end

  def build_review_params
    params.require(:build_review).permit(:reason, :feedback, :result, :ticket_multiplier, :ticket_offset, :tier_override, :hours_override)
  end

  def update_project_review_status(project, build_review)
    case build_review.result
    when "rejected"
      # Only invalidate non-approved reviews to preserve journal entry cutoffs
      project.build_reviews.where.not(id: build_review.id).where.not(result: "approved").update_all(invalidated: true)
      project.update!(review_status: :build_rejected)
    when "returned"
      # Only invalidate non-approved reviews to preserve journal entry cutoffs
      project.build_reviews.where.not(id: build_review.id).where.not(result: "approved").update_all(invalidated: true)
      project.update!(review_status: :build_needs_revision)
    when "approved"
      valid_approvals = project.build_reviews.where(result: "approved", invalidated: false)
      admin_approvals = valid_approvals.where(admin_review: true)

      if valid_approvals.count >= 2 || admin_approvals.exists?
        project.update!(review_status: :build_approved)
      end
    end
  end

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
