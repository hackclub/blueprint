class GorseSyncProjectJob < ApplicationJob
  queue_as :background

  def perform(project_id)
    project = Project
      .left_joins(:journal_entries)
      .select("projects.*, MAX(journal_entries.updated_at) as latest_journal_update")
      .group("projects.id")
      .find(project_id)

    GorseService.sync_item(project)
  rescue => e
    Rails.logger.error("Failed to sync project #{project_id} to Gorse: #{e.message}")
    Sentry.capture_exception(e)
    raise
  end
end
