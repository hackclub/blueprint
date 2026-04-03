module GuildSpamProtection
  extend ActiveSupport::Concern

  private

  def disposable_email?(email)
    domain = email.to_s.strip.downcase.split("@").last
    return false if domain.blank?

    if GuildSignupProtection.disposable_domain?(domain)
      log_signup_attempt(client_ip, email: email, blocked: true, reason: "disposable email: #{domain}")
      notify_admin_channel("Blocked disposable email signup: #{email} (#{domain}), IP: #{client_ip}")
      true
    else
      false
    end
  end

  def check_ip_rate_limit!(redirect_path, email: nil, city: nil, name: nil, slack_id: nil)
    ip = client_ip
    hourly_key = "guild_signup_ip:#{ip}:#{Time.current.strftime('%Y%m%d%H')}"
    daily_key = "guild_signup_ip:#{ip}:#{Time.current.strftime('%Y%m%d')}"

    hourly_count = Rails.cache.increment(hourly_key, 1, expires_in: 1.hour) || 1
    daily_count = Rails.cache.increment(daily_key, 1, expires_in: 24.hours) || 1

    log_signup_attempt(ip, email: email, city: city, blocked: hourly_count > 8 || daily_count > 12)

    if hourly_count > 8 || daily_count > 12
      detail = hourly_count > 2 ? "#{hourly_count} attempts this hour" : "#{daily_count} attempts today"
      notify_admin_channel("! Rate limited signup attempt from IP #{ip} (#{detail}). Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
      redirect_to redirect_path, alert: "You've made too many signup attempts. Please try again later."
      return true
    end

    false
  end

  def check_honeypot!(redirect_path, email: nil, city: nil, name: nil, slack_id: nil)
    honeypot_value = (params[:website].presence || params.dig(:guild_signup, :website)).to_s.strip
    return false if honeypot_value.blank?

    log_signup_attempt(client_ip, email: email, city: city, blocked: true, reason: "honeypot: #{honeypot_value}")
    notify_admin_channel("! Honeypot triggered! Value: #{honeypot_value}, IP: #{client_ip}, Name: #{name || 'N/A'}, Email: #{email || 'N/A'}, City: #{city || 'N/A'}#{slack_id.present? ? ", Slack: <@#{slack_id}>" : ""}")
    redirect_to redirect_path
    true
  end

  def log_signup_attempt(ip, email: nil, city: nil, blocked: false, reason: nil)
    log_key = "guild_signup_log:#{ip}"
    attempts = Rails.cache.read(log_key) || []
    attempts << { email: email, city: city, blocked: blocked, reason: reason, at: Time.current.iso8601 }
    Rails.cache.write(log_key, attempts.last(20), expires_in: 7.days)

    flagged_ips = Rails.cache.read("guild_signup_flagged_ips") || []
    unless flagged_ips.include?(ip)
      flagged_ips << ip
      Rails.cache.write("guild_signup_flagged_ips", flagged_ips, expires_in: 7.days)
    end
  end

  def notify_admin_channel(message)
    return unless ENV["GUILDS_ADMIN_CHANNEL"].present?
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.chat_postMessage(channel: ENV["GUILDS_ADMIN_CHANNEL"], text: message)
  rescue => e
    Rails.logger.error "Failed to notify admin channel: #{e.message}"
  end

  def apply_birthday(user, birthday_raw, error_redirect_path:)
    begin
      birthday_date = Date.parse(birthday_raw.to_s)
    rescue ArgumentError
      redirect_to error_redirect_path, alert: "Invalid date format."
      return :redirected
    end

    age = ((Time.zone.now - birthday_date.to_time) / 1.year.seconds).floor

    if age < 13
      user.update!(birthday: birthday_date, is_banned: true, ban_type: :age)
      redirect_to sorry_path, alert: "You must be at least 13 years old to use Blueprint."
      return :redirected
    end

    if age > 18
      user.update!(birthday: birthday_date)
      redirect_to adult_path
      return :redirected
    end

    user.update!(birthday: birthday_date)
    nil
  end
end
