class AirtableSyncJob < ApplicationJob
  queue_as :background

  CLASSES_TO_SYNC = %w[User Project ShopOrder DesignReview BuildReview].freeze

  def perform(*args)
    CLASSES_TO_SYNC.each do |classname|
      AirtableSyncClassJob.perform_later(classname)
    end
  end
end
