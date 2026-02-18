class AiReview < ApplicationRecord
  belongs_to :project

  enum :status, { queued: "queued", running: "running", completed: "completed", failed: "failed" }, prefix: true
  enum :review_phase, { design: "design", build: "build" }, prefix: true

  validates :review_phase, presence: true
  validates :status, presence: true

  scope :latest_for, ->(project_id, phase) {
    where(project_id: project_id, review_phase: phase)
      .order(created_at: :desc)
      .limit(1)
  }
end
