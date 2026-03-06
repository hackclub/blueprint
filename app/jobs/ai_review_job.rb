class AiReviewJob < ApplicationJob
  queue_as :ai_reviewer

  def perform(project_id, review_phase, force: false, ai_review_id: nil)
    project = Project.find_by(id: project_id)
    ai_review = AiReview.find_by(id: ai_review_id) if ai_review_id

    unless project
      Rails.logger.warn("[AiReviewer] Job skipped: project ##{project_id} not found")
      ai_review&.update!(status: :failed, error_message: "Project not found", completed_at: Time.current)
      return
    end

    unless force
      if %w[hackpad led].include?(project.ysws)
        Rails.logger.info("[AiReviewer] Job skipped: project ##{project_id} is #{project.ysws} (not supported)")
        ai_review&.update!(status: :failed, error_message: "Unsupported ysws type: #{project.ysws}", completed_at: Time.current)
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
        ai_review&.update!(status: :failed, error_message: "Skipped: recent review exists", completed_at: Time.current)
        return
      end
    end

    Rails.logger.info("[AiReviewer] Job starting for project ##{project_id} (#{review_phase})")
    ai_review ||= AiReview.create!(project: project, review_phase: review_phase, status: :queued)
    AiReviewer::ReviewProject.new(project: project, review_phase: review_phase, ai_review: ai_review).call
  end
end
