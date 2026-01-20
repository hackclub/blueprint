class Admin::BuildReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_next, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_next, :create ]

  def index
    # Release any build review session the current user has
    released = Reviews::ClaimProject.release_all_for_reviewer!(reviewer: current_user, type: :build)
    flash.now[:notice] = "Review session ended." if released > 0

    # Only consider non-approved reviews to allow resubmitted projects to be visible
    reviewed_ids = Project.joins(:build_reviews)
                            .where(is_deleted: false, review_status: :build_pending)
                            .where(build_reviews: { invalidated: false })
                            .where.not(build_reviews: { result: BuildReview.results[:approved] })
                            .distinct
                            .pluck(:id)

    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'build_pending')"
    us_priority_sql = "CASE WHEN COALESCE(NULLIF((SELECT idv_country FROM users WHERE users.id = projects.user_id), ''), (SELECT country FROM ahoy_visits WHERE ahoy_visits.user_id = projects.user_id AND country IS NOT NULL AND country != '' ORDER BY started_at DESC LIMIT 1)) IN ('US', 'United States') THEN 0 ELSE 1 END"

    claim_cutoff = Reviews::ClaimProject::TTL.ago

    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .includes(:journal_entries, :build_review_claimed_by, user: :latest_locatable_visit)
                        .select("projects.*, CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN true ELSE false END AS pre_reviewed, #{waiting_since_sql} AS waiting_since")
                        .order(Arel.sql("CASE WHEN id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END, #{us_priority_sql}, created_at ASC"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .where.not(id: reviewed_ids)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .includes(:journal_entries, :build_review_claimed_by, user: :latest_locatable_visit)
                        .select("projects.*, #{waiting_since_sql} AS waiting_since")
                        .order(Arel.sql("#{us_priority_sql}, created_at ASC"))
    end

    @claim_cutoff = claim_cutoff

    @top_reviewers_all_time = User.joins(:build_reviews)
                                  .group("users.id")
                                  .select("users.*, COUNT(build_reviews.id) AS reviews_count")
                                  .order("reviews_count DESC")

    @top_reviewers_week = User.joins(:build_reviews)
                              .where("build_reviews.created_at >= ?", 7.days.ago)
                              .group("users.id")
                              .select("users.*, COUNT(build_reviews.id) AS reviews_count")
                              .order("reviews_count DESC")
  end

  def show
    @project = Project.includes(:build_review_claimed_by).find(params[:id])
    not_found unless @project

    had_any_claim = Reviews::ClaimProject.has_any_claim?(reviewer: current_user, type: :build)
    claimed = Reviews::ClaimProject.call!(project: @project, reviewer: current_user, type: :build)
    @project.reload

    flash.now[:notice] = "Review session started." if claimed && !had_any_claim
    @claimed_by_other = Reviews::ClaimProject.claimed_by_other?(project: @project, reviewer: current_user, type: :build)
    @build_review = @project.build_reviews.build
  end

  def show_next
    project_id = next_project_in_queue(:build, after_project_id: params[:after])

    if project_id
      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_build_review_path(project_id, redirect_params)
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
      Reviews::ClaimProject.release!(project: @project, reviewer: current_user, type: :build)
      update_project_review_status(@project, @build_review)

      redirect_params = { after: @project.id }
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_next_build_review_path(redirect_params), notice: "Build review submitted successfully."
    else
      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_build_review_path(@project, redirect_params), alert: @build_review.errors.full_messages.to_sentence
    end
  end

  private

  def next_project_in_queue(type, after_project_id: nil)
    claim_cutoff = Reviews::ClaimProject::TTL.ago
    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'build_pending')"

    # Get reviewed project IDs (for non-admin filtering) - only non-approved reviews
    reviewed_ids = Project.joins(:build_reviews)
                          .where(is_deleted: false, review_status: :build_pending)
                          .where(build_reviews: { invalidated: false })
                          .where.not(build_reviews: { result: BuildReview.results[:approved] })
                          .distinct
                          .pluck(:id)

    # Base query: active, build_pending, not own project, not claimed by others
    base = Project.active.build_pending.where.not(user_id: current_user.id)
                  .where("build_review_claimed_by_id IS NULL OR build_review_claimed_at IS NULL OR build_review_claimed_at < ? OR build_review_claimed_by_id = ?", claim_cutoff, current_user.id)

    # Non-admins can't see already-reviewed or LED projects
    unless current_user.admin?
      base = base.where.not(id: reviewed_ids).where("ysws IS NULL OR ysws != ?", "led")
    end

    # Apply ysws filter
    base = apply_ysws_filter(base)

    # If after_project_id is provided, only show projects waiting less time (came after in queue)
    if after_project_id.present?
      after_project = Project.find_by(id: after_project_id)
      if after_project
        after_waiting_since = Project.where(id: after_project_id)
                                     .select(waiting_since_sql)
                                     .take
                                     &.attributes&.values&.first
        if after_waiting_since
          base = base.where("#{waiting_since_sql} > ?", after_waiting_since)
        end
      end
    end

    # Order by waiting time (longest first) and pick the first one
    base.select("projects.id, #{waiting_since_sql} AS waiting_since")
        .order(Arel.sql("#{waiting_since_sql} ASC NULLS LAST"))
        .limit(1)
        .pick(:id)
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
