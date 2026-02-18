class AiReview < ApplicationRecord
  belongs_to :project

  enum :status, { queued: "queued", running: "running", completed: "completed", failed: "failed" }, prefix: true
  enum :review_phase, { design: "design", build: "build" }, prefix: true

  validates :review_phase, presence: true
  validates :status, presence: true

  STALE_THRESHOLD = 15.minutes

  scope :latest_for, ->(project_id, phase) {
    where(project_id: project_id, review_phase: phase)
      .order(created_at: :desc)
      .limit(1)
  }

  scope :stale_running, -> {
    where(status: :running).where("started_at < ?", STALE_THRESHOLD.ago)
  }

  def self.fail_stale_reviews!
    stale_running.find_each do |review|
      review.update!(
        status: :failed,
        error_message: "Timed out: review was stuck in running state for over #{STALE_THRESHOLD.inspect}",
        completed_at: Time.current
      )
      Rails.logger.warn("[AiReviewer] Marked stale AiReview ##{review.id} (project ##{review.project_id}) as failed")
    end
  end
end
