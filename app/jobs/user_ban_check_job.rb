class UserBanCheckJob < ApplicationJob
  queue_as :background

  def perform
    Rails.logger.info "UserBanCheckJob started at #{Time.current}"

    users_checked = 0
    users_banned = 0
    users_unbanned = 0

    User.where.not(slack_id: [ nil, "" ]).find_each do |user|
      users_checked += 1

      if is_hackatime_banned?(user.slack_id)
        unless user.is_banned && user.ban_type == "hackatime"
          user.update!(is_banned: true, ban_type: :hackatime)
          users_banned += 1
          Rails.logger.info "User #{user.id} (#{user.slack_id}) banned for Hackatime"
        end
      else
        if user.is_banned && user.ban_type == "hackatime"
          user.update!(is_banned: false, ban_type: nil)
          users_unbanned += 1
          Rails.logger.info "User #{user.id} (#{user.slack_id}) unbanned from Hackatime"
        end
      end
    end

    Rails.logger.info "UserBanCheckJob completed: checked #{users_checked}, banned #{users_banned}, unbanned #{users_unbanned}"
  end

  private

  def is_hackatime_banned?(slack_id)
    response = Faraday.get("https://hackatime.hackclub.com/api/v1/users/#{slack_id}/trust_factor")

    unless response.success?
      if response.status == 404
        Rails.logger.info("User #{slack_id} does not have a Hackatime account")
        return false
      end

      Rails.logger.error("Hackatime API returned non-success status for #{slack_id}: #{response.status}")
      Sentry.capture_message("Hackatime API failed for user #{slack_id}: #{response.status} - #{response.body}")
      return false
    end

    data = JSON.parse(response.body)
    data["trust_level"] == "red"
  rescue => e
    Rails.logger.error("Failed to check Hackatime ban status for #{slack_id}: #{e.message}")
    Sentry.capture_exception(e)
    false
  end
end
