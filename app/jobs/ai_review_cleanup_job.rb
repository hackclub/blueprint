class AiReviewCleanupJob < ApplicationJob
  queue_as :background

  def perform
    AiReview.fail_stale_reviews!
  end
end
