class GorseSyncViewJob < ApplicationJob
  queue_as :background

  def perform(user_id, item_id, timestamp, item_type: "Project")
    item = case item_type
    when "JournalEntry"
             JournalEntry.find(item_id)
    when "Project"
             Project.find(item_id)
    else
             raise ArgumentError, "Unknown item_type: #{item_type}"
    end

    GorseService.sync_feedback("view", user_id, item, timestamp)
  rescue => e
    Rails.logger.error("Failed to sync view feedback to Gorse for #{item_type} #{item_id}: #{e.message}")
    Sentry.capture_exception(e)
    raise
  end
end
