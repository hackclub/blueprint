class RefreshIdvDataJob < ApplicationJob
  queue_as :background

  def perform
    User.find_each do |user|
      user.refresh_idv_data!
    rescue Faraday::UnauthorizedError => e
      Rails.logger.warn("IDV refresh failed for user #{user.id}: #{e.message}")
      Sentry.capture_exception(e, extra: { user_id: user.id })
    end
  end
end
