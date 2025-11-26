class GorseSyncFollowJob < ApplicationJob
  queue_as :background

  def perform(follow_id)
    follow = Follow.find(follow_id)
    project = Project.find(follow.project_id)
    GorseService.sync_feedback("follow", follow.user_id, project, follow.created_at)
  rescue => e
    Rails.logger.error("Failed to sync follow #{follow_id} to Gorse: #{e.message}")
    Sentry.capture_exception(e)
    raise
  end
end
