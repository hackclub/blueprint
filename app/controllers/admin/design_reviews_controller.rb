class Admin::DesignReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_random, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_random, :create ]

  def index
    reviewed_ids = Project.joins(:design_reviews)
                            .where(is_deleted: false, review_status: :design_pending)
                            .where(design_reviews: { invalidated: false })
                            .distinct
                            .pluck(:id)
    us_priority_sql = "CASE WHEN COALESCE(NULLIF((SELECT idv_country FROM users WHERE users.id = projects.user_id), ''), (SELECT country FROM ahoy_visits WHERE ahoy_visits.user_id = projects.user_id AND country IS NOT NULL AND country != '' ORDER BY started_at DESC LIMIT 1)) IN ('US', 'United States') THEN 0 ELSE 1 END"

    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .includes(:journal_entries, user: :latest_locatable_visit)
                        .select("projects.*, CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN true ELSE false END AS pre_reviewed")
                        .order(Arel.sql("CASE WHEN id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END, #{us_priority_sql}, created_at ASC"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .where.not(id: reviewed_ids)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .includes(:journal_entries, user: :latest_locatable_visit)
                        .order(Arel.sql("#{us_priority_sql}, created_at ASC"))
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
    reviewed = apply_ysws_filter(base.with_valid_design_review)
    unreviewed = apply_ysws_filter(base.without_valid_design_review)

    us_filter = ->(scope) {
      scope.where("COALESCE(NULLIF((SELECT idv_country FROM users WHERE users.id = projects.user_id), ''), (SELECT country FROM ahoy_visits WHERE ahoy_visits.user_id = projects.user_id AND country IS NOT NULL AND country != '' ORDER BY started_at DESC LIMIT 1)) IN ('US', 'United States')")
    }

    project_id =
      if current_user.admin?
        random_pick_id(us_filter.call(reviewed)) ||
        random_pick_id(reviewed) ||
        random_pick_id(us_filter.call(unreviewed)) ||
        random_pick_id(unreviewed)
      else
        random_pick_id(us_filter.call(unreviewed)) ||
        random_pick_id(unreviewed)
      end

    if project_id
      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_design_review_path(project_id, redirect_params)
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
        ysws_value = params[:design_review][:ysws] == "none" ? nil : params[:design_review][:ysws]
        @project.update(ysws: ysws_value)
      end
      update_project_review_status(@project, @design_review)

      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_random_design_review_path(redirect_params), notice: "Design review submitted successfully. Showing new project."
    else
      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_design_review_path(@project, redirect_params), alert: @design_review.errors.full_messages.to_sentence
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

  def normalized_ysws_filter
    valid_types = %w[hackpad squeak devboard midi splitkb led custom]
    valid_types.include?(params[:ysws_type]) ? params[:ysws_type] : nil
  end

  def apply_ysws_filter(scope)
    filter = normalized_ysws_filter
    if filter == "custom"
      scope.where(ysws: nil)
    elsif filter.present?
      scope.where(ysws: filter)
    elsif current_user.admin?
      scope
    else
      scope.where("ysws IS NULL OR ysws != ?", "led")
    end
  end
end
