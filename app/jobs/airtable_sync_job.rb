class AirtableSyncJob < ApplicationJob
  queue_as :background

  def perform(*args)
    classes_to_sync = [ User.name, Project.name, ShopOrder.name ]

    classes_to_sync.each do |classname|
      AirtableSync.sync!(classname)
    end
  end
end
