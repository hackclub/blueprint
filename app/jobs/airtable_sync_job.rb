class AirtableSyncJob < ApplicationJob
  queue_as :background

  def perform(*args)
    classes_to_sync = [ User.name, Project.name, ShopOrder.name ]

    errors = []

    classes_to_sync.each do |classname|
      AirtableSync.sync!(classname)
    rescue => e
      Sentry.capture_exception(e, extra: { airtable_sync_class: classname })
      errors << { classname: classname, error: e }
    end

    Rails.logger.error("AirtableSync failed for: #{errors.map { |e| e[:classname] }.join(', ')}") if errors.any?
  end
end
