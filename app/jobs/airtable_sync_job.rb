class AirtableSyncJob < ApplicationJob
  queue_as :background

  def perform(*args)
    classes_to_sync = [ User.name, Project.name, ShopOrder.name ]

    classes_to_sync.each do |classname|
      Sentry.with_scope do |scope|
        scope.set_tags(airtable_sync_class: classname)
        AirtableSync.sync!(classname)
      end
    end
  end
end
