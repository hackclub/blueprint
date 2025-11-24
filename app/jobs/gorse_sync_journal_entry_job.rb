class GorseSyncJournalEntryJob < ApplicationJob
  queue_as :background

  def perform(entry_id)
    entry = JournalEntry.find(entry_id)
    GorseService.sync_item(entry)
  rescue => e
    Rails.logger.error("Failed to sync journal entry #{entry_id} to Gorse: #{e.message}")
    Sentry.capture_exception(e)
    raise
  end
end
