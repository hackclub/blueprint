class Admin::DesignReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_next, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_next, :create ]

  def index
    # Release any design review session the current user has
    released = Reviews::ClaimProject.release_all_for_reviewer!(reviewer: current_user, type: :design)
    flash.now[:notice] = "Review session ended." if released > 0

    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'design_pending')"
    first_waiting_since_sql = "(SELECT MIN(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'design_pending')"

    claim_cutoff = Reviews::ClaimProject::TTL.ago

    # Use EXISTS/NOT EXISTS subqueries instead of interpolated IN (...) for better performance and NULL safety
    pre_reviewed_exists_sql = "EXISTS (SELECT 1 FROM design_reviews WHERE design_reviews.project_id = projects.id AND design_reviews.invalidated = FALSE)"
    not_reviewed_exists_sql = "NOT EXISTS (SELECT 1 FROM design_reviews WHERE design_reviews.project_id = projects.id AND design_reviews.invalidated = FALSE)"

    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .left_joins(:journal_entries)
                        .includes(:design_review_claimed_by, :latest_journal_entry, :demo_picture_attachment, user: :latest_locatable_visit)
                        .select(
                          "projects.*",
                          "(#{pre_reviewed_exists_sql}) AS pre_reviewed",
                          "#{waiting_since_sql} AS waiting_since",
                          "#{first_waiting_since_sql} AS first_waiting_since",
                          "COALESCE(SUM(journal_entries.duration_seconds), 0) AS total_duration_seconds",
                          "COUNT(journal_entries.id) AS journal_entries_count"
                        )
                        .group("projects.id")
                        .order(Arel.sql("CASE WHEN (#{pre_reviewed_exists_sql}) THEN 0 ELSE 1 END, waiting_since ASC NULLS LAST"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :design_pending)
                        .where(not_reviewed_exists_sql)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .left_joins(:journal_entries)
                        .includes(:design_review_claimed_by, :latest_journal_entry, :demo_picture_attachment, user: :latest_locatable_visit)
                        .select(
                          "projects.*",
                          "#{waiting_since_sql} AS waiting_since",
                          "#{first_waiting_since_sql} AS first_waiting_since",
                          "COALESCE(SUM(journal_entries.duration_seconds), 0) AS total_duration_seconds",
                          "COUNT(journal_entries.id) AS journal_entries_count"
                        )
                        .group("projects.id")
                        .order(Arel.sql("waiting_since ASC NULLS LAST"))
    end

    @claim_cutoff = claim_cutoff

    @top_reviewers_all_time = User.joins(:design_reviews)
                                  .group("users.id")
                                  .select("users.*, COUNT(design_reviews.id) AS reviews_count")
                                  .order("reviews_count DESC")
                                  .limit(10)

    @top_reviewers_week = User.joins(:design_reviews)
                              .where("design_reviews.created_at >= ?", Time.current.beginning_of_week)
                              .group("users.id")
                              .select("users.*, COUNT(design_reviews.id) AS reviews_count")
                              .order("reviews_count DESC")
                              .limit(10)

    @top_reviewers_payouts = User.joins(:design_reviews)
                                 .where("design_reviews.created_at >= ?", Date.new(2026, 3, 23))
                                 .group("users.id")
                                 .select("users.*, COUNT(design_reviews.id) AS reviews_count")
                                 .order("reviews_count DESC")
                                 .limit(10)

    @total_pending_hours = JournalEntry.joins(:project)
                                       .where(projects: { is_deleted: false, review_status: :design_pending })
                                       .sum(:duration_seconds) / 3600.0
  end

  def show
    @project = Project.includes(:design_review_claimed_by).find(params[:id])
    not_found unless @project

    had_any_claim = Reviews::ClaimProject.has_any_claim?(reviewer: current_user, type: :design)
    claimed = Reviews::ClaimProject.call!(project: @project, reviewer: current_user, type: :design)
    @project.reload

    flash.now[:notice] = "Review session started." if claimed && !had_any_claim
    @claimed_by_other = Reviews::ClaimProject.claimed_by_other?(project: @project, reviewer: current_user, type: :design)
    @design_review = @project.design_reviews.build
    @ai_review = @project.latest_ai_review("design") if Flipper.enabled?(:ai_reviewer)

    # Waiting time: last and first time project entered design_pending
    pending_versions = PaperTrail::Version.where(item_type: "Project", item_id: @project.id, event: "update")
                        .where("jsonb_exists(object_changes, 'review_status')")
                        .where("object_changes->'review_status'->>1 = ?", "design_pending")
    @waiting_since = pending_versions.maximum(:created_at)
    @first_waiting_since = pending_versions.minimum(:created_at)
  end

  def show_next
    exclude_ids = params[:skipped].to_s.split(",").map(&:to_i).reject(&:zero?)
    project_id = next_project_in_queue(:design, exclude_ids: exclude_ids)

    if project_id
      redirect_params = {}
      redirect_params[:skipped] = params[:skipped] if params[:skipped].present?
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
      Reviews::ClaimProject.release!(project: @project, reviewer: current_user, type: :design)
      if current_user.admin? && params[:design_review][:ysws].present?
        ysws_value = params[:design_review][:ysws] == "none" ? nil : params[:design_review][:ysws]
        @project.update(ysws: ysws_value)
      end
      update_project_review_status(@project, @design_review)

      redirect_params = {}
      redirect_params[:skipped] = params[:skipped] if params[:skipped].present?
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_next_design_review_path(redirect_params), notice: "Design review submitted successfully."
    else
      redirect_params = {}
      redirect_params[:ysws_type] = normalized_ysws_filter if normalized_ysws_filter.present?
      redirect_to admin_design_review_path(@project, redirect_params), alert: @design_review.errors.full_messages.to_sentence
    end
  end

  private

  def next_project_in_queue(type, exclude_ids: [])
    claim_cutoff = Reviews::ClaimProject::TTL.ago
    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'design_pending')"

    # Get reviewed project IDs (for non-admin filtering and admin prioritization)
    reviewed_ids = Project.joins(:design_reviews)
                          .where(is_deleted: false, review_status: :design_pending)
                          .where(design_reviews: { invalidated: false })
                          .distinct
                          .pluck(:id)

    # Base query: active, design_pending, not own project, not claimed by others
    base = Project.active.design_pending.where.not(user_id: current_user.id)
                  .where("design_review_claimed_by_id IS NULL OR design_review_claimed_at IS NULL OR design_review_claimed_at < ? OR design_review_claimed_by_id = ?", claim_cutoff, current_user.id)

    # Non-admins can't see already-reviewed or LED projects
    unless current_user.admin?
      base = base.where.not(id: reviewed_ids).where("ysws IS NULL OR ysws != ?", "led")
    end

    # Apply ysws filter
    base = apply_ysws_filter(base)

    # Exclude specifically skipped projects
    base = base.where.not(id: exclude_ids) if exclude_ids.any?

    # For admins, prioritize pre-reviewed projects first, then by waiting time
    if current_user.admin?
      pre_reviewed_sql = "CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END"
      base.select("projects.id, #{waiting_since_sql} AS waiting_since")
          .order(Arel.sql("#{pre_reviewed_sql}, #{waiting_since_sql} ASC NULLS LAST"))
          .limit(1)
          .pick(:id)
    else
      # Non-admins: order by waiting time only (pre-reviewed already excluded)
      base.select("projects.id, #{waiting_since_sql} AS waiting_since")
          .order(Arel.sql("#{waiting_since_sql} ASC NULLS LAST"))
          .limit(1)
          .pick(:id)
    end
  end

  def accumulated_skipped(project)
    [params[:skipped], project.id].compact_blank.join(",")
  end
  helper_method :accumulated_skipped

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
    valid_types = %w[hackpad squeak devboard midi splitkb led custom devboard_by_name keyboard_by_name]
    valid_types.include?(params[:ysws_type]) ? params[:ysws_type] : nil
  end

  def apply_ysws_filter(scope)
    filter = normalized_ysws_filter
    if filter == "custom"
      scope.where(ysws: nil)
    elsif filter == "devboard_by_name"
      scope.where("title ILIKE :q OR description ILIKE :q", q: "%devboard%")
    elsif filter == "keyboard_by_name"
      scope.where("title ILIKE :q OR description ILIKE :q", q: "%keyboard%")
    elsif filter.present?
      scope.where(ysws: filter)
    elsif current_user.admin?
      scope
    else
      scope.where("ysws IS NULL OR ysws != ?", "led")
    end
  end
end
