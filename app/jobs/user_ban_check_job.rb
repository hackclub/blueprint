class UserBanCheckJob < ApplicationJob
  queue_as :background

  # Ban priority: higher priority bans take precedence
  BAN_PRIORITY = [ :blueprint, :hardware, :slack, :age, :hackatime ].freeze

  def perform
    Rails.logger.info "UserBanCheckJob started at #{Time.current}"

    max_threads = ENV.fetch("MAX_BACKGROUND_JOB_THREADS", "6").to_i.clamp(1, 6)
    Rails.logger.info "Using #{max_threads} threads for ban checking"

    users = User.where.not(slack_id: [ nil, "" ]).to_a

    mutex = Mutex.new
    counters = { checked: 0, banned: 0, unbanned: 0 }

    users.each_slice((users.size.to_f / max_threads).ceil).map do |user_batch|
      Thread.new do
        user_batch.each do |user|
          begin
            mutex.synchronize { counters[:checked] += 1 }
            check_user_bans(user, mutex, counters)
          rescue => e
            Rails.logger.error("Error processing user #{user.id}: #{e.message}")
            Sentry.capture_exception(e)
          end
        end
      end
    end.each(&:join)

    Rails.logger.info "UserBanCheckJob completed: checked #{counters[:checked]}, banned #{counters[:banned]}, unbanned #{counters[:unbanned]}"
  end

  private

  def check_user_bans(user, mutex, counters)
    # Check bans in priority order
    BAN_PRIORITY.each do |ban_type|
      should_ban = case ban_type
      when :blueprint
        is_blueprint_banned?(user)
      when :hardware
        is_hardware_banned?(user)
      when :slack
        is_slack_banned?(user)
      when :age
        is_age_banned?(user)
      when :hackatime
        is_hackatime_banned?(user.slack_id)
      else
        false
      end

      if should_ban
        # User should be banned for this type
        unless user.is_banned && user.ban_type == ban_type.to_s
          user.update!(is_banned: true, ban_type: ban_type)
          mutex.synchronize { counters[:banned] += 1 }
          Rails.logger.info "User #{user.id} (#{user.slack_id}) banned for #{ban_type}"
        end
        return # Stop checking lower priority bans
      end
    end

    # If we reach here, no bans apply - unban if currently banned
    if user.is_banned
      user.update!(is_banned: false, ban_type: nil)
      mutex.synchronize { counters[:unbanned] += 1 }
      Rails.logger.info "User #{user.id} (#{user.slack_id}) unbanned"
    end
  end

  def is_blueprint_banned?(user)
    # TODO: Implement blueprint ban check
    false
  end

  def is_hardware_banned?(user)
    # TODO: Implement hardware ban check
    false
  end

  def is_slack_banned?(user)
    # TODO: Implement slack ban check
    false
  end

  def is_age_banned?(user)
    # TODO: Implement age ban check
    false
  end

  def is_hackatime_banned?(slack_id)
    return false if slack_id.blank?

    response = Faraday.get("https://hackatime.hackclub.com/api/v1/users/#{slack_id}/trust_factor")

    unless response.success?
      if response.status == 404
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
