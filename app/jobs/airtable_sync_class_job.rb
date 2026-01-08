class AirtableSyncClassJob < ApplicationJob
  queue_as :background

  def perform(classname)
    AirtableSync.sync!(classname)
  rescue => e
    Sentry.capture_exception(e, extra: { airtable_sync_class: classname })
    raise e
  end
end
