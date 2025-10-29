class ApiController < ApplicationController
  allow_unauthenticated_access only: %i[ site stickers report_grant_given report_free_stickers_claimed ]
  skip_forgery_protection only: %i[ site stickers report_grant_given report_free_stickers_claimed ]
  before_action :authenticate_api, only: %i[ stickers report_grant_given report_free_stickers_claimed ]

  def site
    render plain: "#{Project.where(is_deleted: false).count} projects made"
  end

  def stickers
    # check to make sure the request has slack_id and blueprint_id
    slack_id = params[:slack_id]
    blueprint_id = params[:blueprint_id]
    unless slack_id.present? && blueprint_id.present?
      render json: { ok: false, error: "Missing fields" }, status: :bad_request
      return
    end

    user = User.find_by(id: blueprint_id, slack_id: slack_id)
    unless user
      render json: { ok: false, error: "User not found" }, status: :not_found
      return
    end

    eligible = user.tasks.completed?
    render json: { ok: true, eligible: eligible }
  end

  def report_grant_given
    project_id = params[:project_id]
    amount_cents = params[:amount_cents]
    tier = params[:tier]

    unless project_id.present? && amount_cents.present? && tier.present?
      render json: { ok: false, error: "Missing fields" }, status: :bad_request
      return
    end

    project = Project.find_by(id: project_id, is_deleted: false)
    unless project
      render json: { ok: false, error: "Project not found" }, status: :not_found
      return
    end

    project.report_grant_given!(amount_cents.to_i, tier)
    render json: { ok: true }
  end

  def report_free_stickers_claimed
    user_id = params[:user_id]

    unless user_id.present?
      render json: { ok: false, error: "Missing fields" }, status: :bad_request
      return
    end

    user = User.find_by(id: user_id)
    unless user
      render json: { ok: false, error: "User not found" }, status: :not_found
      return
    end

    user.update!(free_stickers_claimed: true)
    render json: { ok: true }
  end

  private

  def authenticate_api
    unless ENV["BLUEPRINT_API_KEY"].present?
      raise "BLUEPRINT_API_KEY environment variable is not set"
    end

    authenticate_or_request_with_http_token do |token, options|
      ActiveSupport::SecurityUtils.secure_compare(token, ENV["BLUEPRINT_API_KEY"] || "")
    end
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unauthorized
  end
end
