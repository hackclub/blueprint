class AiReviewJob < ApplicationJob
  queue_as :background

  def perform(project_id, review_phase)
    project = Project.find_by(id: project_id)
    unless project
      Rails.logger.warn("[AiReviewer] Job skipped: project ##{project_id} not found")
      return
    end

    recent_completed = project.ai_reviews
      .where(review_phase: review_phase, status: :completed)
      .where("created_at > ?", 1.hour.ago)
      .exists?

    active_running = project.ai_reviews
      .where(review_phase: review_phase, status: :running)
      .where("started_at > ?", AiReview::STALE_THRESHOLD.ago)
      .exists?

    if recent_completed || active_running
      Rails.logger.info("[AiReviewer] Job skipped: project ##{project_id} already has a recent #{review_phase} review")
      return
    end

    Rails.logger.info("[AiReviewer] Job starting for project ##{project_id} (#{review_phase})")
    AiReviewer::ReviewProject.new(project: project, review_phase: review_phase).call
  end
end
