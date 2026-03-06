class Admin::AiReviewsController < Admin::ApplicationController
  include Pagy::Backend

  skip_before_action :require_admin!
  before_action :require_reviewer_perms!

  def index
    @counts = {
      queued: AiReview.status_queued.count,
      running: AiReview.status_running.count,
      completed: AiReview.status_completed.count,
      failed: AiReview.status_failed.count
    }

    reviews = AiReview.includes(:project)

    @status_filter = params[:status]
    reviews = reviews.where(status: @status_filter) if %w[queued running completed failed].include?(@status_filter)

    @phase_filter = params[:phase]
    reviews = reviews.where(review_phase: @phase_filter) if %w[design build].include?(@phase_filter)

    @q = params[:q].to_s.strip
    if @q.present?
      reviews = reviews.where("ai_reviews.project_id::text ILIKE :q", q: "%#{@q}%")
    end

    reviews = reviews.order(created_at: :desc)
    @pagy, @ai_reviews = pagy(reviews, items: 25)
  end

  def show
    @ai_review = AiReview.includes(:project).find(params[:id])
    @project = @ai_review.project
  end

  def create
    project = Project.find(params[:project_id])
    phase = params[:review_phase]

    unless %w[design build].include?(phase)
      redirect_back fallback_location: admin_root_path, alert: "Invalid review phase."
      return
    end

    AiReviewJob.perform_later(project.id, phase, force: true)
    redirect_back fallback_location: admin_root_path, notice: "AI analysis queued. Check back in ~5 minutes."
  end

  private

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
