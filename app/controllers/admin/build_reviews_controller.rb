class Admin::BuildReviewsController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :show_next, :create ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :show_next, :create ]

  def index
    # Release any build review session the current user has
    released = Reviews::ClaimProject.release_all_for_reviewer!(reviewer: current_user, type: :build)
    flash.now[:notice] = "Review session ended." if released > 0

    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'build_pending')"

    claim_cutoff = Reviews::ClaimProject::TTL.ago

    # Use EXISTS/NOT EXISTS subqueries instead of interpolated IN (...) for better performance and NULL safety
    pre_reviewed_exists_sql = "EXISTS (SELECT 1 FROM build_reviews WHERE build_reviews.project_id = projects.id AND build_reviews.invalidated = FALSE)"
    not_reviewed_exists_sql = "NOT EXISTS (SELECT 1 FROM build_reviews WHERE build_reviews.project_id = projects.id AND build_reviews.invalidated = FALSE)"

    # Compute last_review_entry_at in SQL (max journal_entries.created_at from approved admin reviews)
    # Use MAX over VALUES to handle NULLs correctly (GREATEST returns NULL if either arg is NULL)
    build_approved = BuildReview.results.fetch("approved")
    design_approved = DesignReview.results.fetch("approved")

    last_review_entry_at_sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, build_approved, design_approved ])
      (SELECT MAX(ts) FROM (VALUES
        ((SELECT MAX(je.created_at) FROM build_reviews br
          JOIN journal_entries je ON je.review_type = 'BuildReview' AND je.review_id = br.id
          WHERE br.project_id = projects.id AND br.result = ? AND br.invalidated = FALSE AND br.admin_review = TRUE)),
        ((SELECT MAX(je.created_at) FROM design_reviews dr
          JOIN journal_entries je ON je.review_type = 'DesignReview' AND je.review_id = dr.id
          WHERE dr.project_id = projects.id AND dr.result = ? AND dr.invalidated = FALSE AND dr.admin_review = TRUE))
      ) AS v(ts))
    SQL

    if current_user.admin?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .left_joins(:journal_entries)
                        .includes(:build_review_claimed_by, :latest_journal_entry, :demo_picture_attachment, :user)
                        .select(
                          "projects.*",
                          "(#{pre_reviewed_exists_sql}) AS pre_reviewed",
                          "#{waiting_since_sql} AS waiting_since",
                          "#{last_review_entry_at_sql} AS last_review_entry_at",
                          "COALESCE(SUM(CASE WHEN journal_entries.id IS NOT NULL AND (journal_entries.created_at > #{last_review_entry_at_sql} OR #{last_review_entry_at_sql} IS NULL) THEN journal_entries.duration_seconds ELSE 0 END), 0) AS hours_since_last_review_seconds",
                          "COUNT(CASE WHEN journal_entries.id IS NOT NULL AND (journal_entries.created_at > #{last_review_entry_at_sql} OR #{last_review_entry_at_sql} IS NULL) THEN 1 END) AS entries_since_last_review_count"
                        )
                        .group("projects.id")
                        .order(Arel.sql("CASE WHEN (#{pre_reviewed_exists_sql}) THEN 0 ELSE 1 END, waiting_since ASC NULLS LAST"))
    elsif current_user.reviewer_perms?
      @projects = Project.where(is_deleted: false, review_status: :build_pending)
                        .where(not_reviewed_exists_sql)
                        .where("ysws IS NULL OR ysws != ?", "led")
                        .left_joins(:journal_entries)
                        .includes(:build_review_claimed_by, :latest_journal_entry, :demo_picture_attachment, :user)
                        .select(
                          "projects.*",
                          "#{waiting_since_sql} AS waiting_since",
                          "#{last_review_entry_at_sql} AS last_review_entry_at",
                          "COALESCE(SUM(CASE WHEN journal_entries.id IS NOT NULL AND (journal_entries.created_at > #{last_review_entry_at_sql} OR #{last_review_entry_at_sql} IS NULL) THEN journal_entries.duration_seconds ELSE 0 END), 0) AS hours_since_last_review_seconds",
                          "COUNT(CASE WHEN journal_entries.id IS NOT NULL AND (journal_entries.created_at > #{last_review_entry_at_sql} OR #{last_review_entry_at_sql} IS NULL) THEN 1 END) AS entries_since_last_review_count"
                        )
                        .group("projects.id")
                        .order(Arel.sql("waiting_since ASC NULLS LAST"))
    end

    @claim_cutoff = claim_cutoff

    @top_reviewers_all_time = User.joins(:build_reviews)
                                  .group("users.id")
                                  .select("users.*, COUNT(build_reviews.id) AS reviews_count")
                                  .order("reviews_count DESC")
                                  .limit(10)

    @top_reviewers_week = User.joins(:build_reviews)
                              .where("build_reviews.created_at >= ?", 7.days.ago)
                              .group("users.id")
                              .select("users.*, COUNT(build_reviews.id) AS reviews_count")
                              .order("reviews_count DESC")
                              .limit(10)
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

    # Get reviewed project IDs (for non-admin filtering)
    reviewed_ids = Project.joins(:build_reviews)
                          .where(is_deleted: false, review_status: :build_pending)
                          .where(build_reviews: { invalidated: false })
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
