class GorseSyncUserJob < ApplicationJob
  queue_as :background

  def perform(user_id)
    user = User.find(user_id)
    GorseService.sync_user(user)
  rescue => e
    Rails.logger.error("Failed to sync user #{user_id} to Gorse: #{e.message}")
    Sentry.capture_exception(e)
    raise
  end
end
