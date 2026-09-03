class RefreshIdvDataJob < ApplicationJob
  queue_as :background

  def perform
    User.pending_idv_refresh.find_each do |user|
      user.refresh_idv_data!
    rescue Faraday::UnauthorizedError, Faraday::BadRequestError => e
      Rails.logger.warn("IDV refresh failed for user #{user.id}: #{e.message}")
      user.clear_idv_tokens!
    end
  end
end
