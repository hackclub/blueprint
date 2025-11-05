class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[show]

  def show
    @user = User.find_by(id: params[:id])
    not_found unless @user
    @projects = @user.projects.where(is_deleted: false).includes(:banner_attachment).order(created_at: :desc)

    # Heatmap data
    @activity_start_date = Date.new(2025, 10, 1)
    @activity_end_date   = Date.new(2026, 1, 1)

    tz = (@user.respond_to?(:timezone_raw) && @user.timezone_raw.presence) || Time.zone.name
    range = @activity_start_date.beginning_of_day..@activity_end_date.end_of_day

    # Build a sanitized group expression: date_trunc('day', created_at AT TIME ZONE ?)::date
    group_sql = ActiveRecord::Base.send(
      :sanitize_sql_array,
      ["date_trunc('day', created_at AT TIME ZONE ?)::date", tz]
    )

    counts = JournalEntry.where(user_id: @user.id, created_at: range)
                         .group(Arel.sql(group_sql))
                         .count

    # Convert keys to ISO date strings for easy lookup in the view
    @activity_by_date = counts.transform_keys { |d| d.to_date.iso8601 }
  end

  def me
    redirect_to user_path(current_user)
  end

  def invite_to_slack
    ahoy.track("slack_user_create", user_id: current_user&.id)
    current_user.invite_to_slack!
    render json: { ok: true, status: "done", user_id: current_user.id }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def mcg_check
    current_user.refresh_profile!
    if current_user.is_mcg?
      ahoy.track("slack_login", from_mcg: true, user_id: current_user&.id)
    end
    render json: { ok: true, status: "done", user_id: current_user.id, is_mcg: current_user.is_mcg? }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def update_timezone
    unless current_user
      render json: { ok: false, error: "Not authenticated" }, status: :unauthorized
      return
    end

    timezone = params[:timezone]
    if timezone.blank?
      render json: { ok: false, error: "Timezone parameter is required" }, status: :bad_request
      return
    end

    if current_user.update_timezone(timezone)
      render json: { ok: true, status: "updated", timezone: current_user.timezone_raw }
    else
      render json: { ok: false, error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :internal_server_error
  end
end
