# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  admin                       :boolean          default(FALSE), not null
#  avatar                      :string
#  ban_type                    :integer
#  birthday                    :date
#  email                       :string           not null
#  free_stickers_claimed       :boolean          default(FALSE), not null
#  fulfiller                   :boolean          default(FALSE), not null
#  github_username             :string
#  identity_vault_access_token :string
#  idv_country                 :string
#  internal_notes              :text
#  is_banned                   :boolean          default(FALSE), not null
#  is_mcg                      :boolean          default(FALSE), not null
#  is_pro                      :boolean          default(FALSE)
#  last_active                 :datetime
#  reviewer                    :boolean          default(FALSE), not null
#  timezone_raw                :string
#  username                    :string
#  ysws_verified               :boolean
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  github_installation_id      :bigint
#  identity_vault_id           :string
#  referrer_id                 :bigint
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_referrer_id  (referrer_id)
#
# Foreign Keys
#
#  fk_rails_...  (referrer_id => users.id)
#
class User < ApplicationRecord
  # Fail safe in case i'm stupid
  def to_s
    "User##{id}"
  end

  has_many :projects
  has_many :journal_entries
  has_many :follows, dependent: :destroy
  has_many :followed_projects, through: :follows, source: :project
  has_many :design_reviews, foreign_key: :reviewer_id, dependent: :destroy
  has_many :build_reviews, foreign_key: :reviewer_id, dependent: :destroy
  has_many :received_build_reviews, through: :projects, source: :build_reviews
  has_many :manual_ticket_adjustments, dependent: :destroy
  has_one :task_list, dependent: :destroy
  has_many :kudos, dependent: :destroy
  has_many :shop_orders, dependent: :destroy

  has_many :ahoy_visits, class_name: "Ahoy::Visit"
  has_many :ahoy_events, class_name: "Ahoy::Event"
  has_one :latest_locatable_visit, -> { where.not(country: [ nil, "" ]).order(started_at: :desc) }, class_name: "Ahoy::Visit"

  def country
    idv_country.presence || latest_locatable_visit&.country
  end

  # Simple referrer: a user may have one referrer (another User)
  belongs_to :referrer, class_name: "User", optional: true

  enum :ban_type, { hackatime: 0, blueprint: 1, previous: 2, slack: 3, age: 4 }

  validates :is_banned, inclusion: { in: [ true, false ] }
  after_commit :advance_projects_after_idv!, on: :update, if: -> { previous_changes.key?("ysws_verified") && ysws_verified? }
  after_commit :sync_to_gorse, on: :create
  after_commit :delete_from_gorse, on: :destroy

  has_paper_trail
  has_recommended :projects
  has_recommended :journal_entries

  def self.airtable_sync_table_id
    "tblfvmJUeNMapzCBl"
  end

  def self.airtable_sync_sync_id
    "6mGZYU5X"
  end

  def self.airtable_sync_field_mappings
    {
      "User ID" => :id,
      "Slack ID" => :slack_id,
      "GitHub Username" => :github_username,
      "Email" => :email,
      "Display Name" => lambda { |user| user.display_name },
      "Avatar" => :avatar,
      "Is Banned" => :is_banned,
      "Is MCG" => :is_mcg,
      "Role" => lambda { |user|
        roles = []
        roles << "Admin" if user.admin?
        roles << "Reviewer" if user.reviewer?
        roles << "Fulfiller" if user.fulfiller?
        roles.any? ? roles : [ "User" ]
      },
      "Timezone" => :timezone_raw,
      "Country" => lambda { |user| user.country },
      "Last Active" => :last_active,
      "YSWS Verified" => :ysws_verified,
      "Created At" => :created_at,
      "Updated At" => :updated_at,
      "Github Linked" => lambda { |user| user.github_user? },
      "Referrer ID" => :referrer_id,
      "Referrer Email" => lambda { |user| user.referrer&.email }
    }
  end

  def self.exchange_slack_token(code, redirect_uri, referrer_id: nil)
    response = Faraday.post("https://slack.com/api/oauth.v2.access",
                            {
                              client_id: ENV.fetch("SLACK_CLIENT_ID", nil),
                              client_secret: ENV.fetch("SLACK_CLIENT_SECRET", nil),
                              redirect_uri: redirect_uri,
                              code: code
                            })

    result = JSON.parse(response.body)

    unless result["ok"]
      Rails.logger.error("Slack OAuth error: #{result['error']}")
      # Honeybadger.notify("Slack OAuth error: #{result['error']}")
      raise StandardError, "Failed to authenticate with Slack: #{result['error']}"
    end

    slack_id = result["authed_user"]["id"]

    user_info = fetch_slack_user_info(slack_id)
    slack_email = user_info.user.profile.email

    user = User.find_by(slack_id: slack_id) || User.find_by(email: slack_email)
    if user.present?
      Rails.logger.tagged("UserCreation") do
        Rails.logger.info({
          event: "existing_user_found",
          slack_id: slack_id,
          user_id: user.id,
          email: user.email
        }.to_json)
      end

      user.refresh_profile!

      unless AllowedEmail.allowed?(user.email)
        raise StandardError, "You do not have access."
      end

      return user
    end

    user = create_from_slack(slack_id, referrer_id: referrer_id)
    user
  end

  def self.create_from_slack(slack_id, referrer_id: nil)
    user_info = fetch_slack_user_info(slack_id)
    if user_info.user.is_bot
      Rails.logger.warn({
        event: "slack_user_is_bot",
        slack_id: slack_id,
        user_info: user_info.to_h
      }.to_json)
      return nil
    end

    email = user_info.user.profile.email
    username_from_slack = user_info.user.profile.display_name.presence || user_info.user.profile.real_name
    timezone = user_info.user.tz
    avatar = user_info.user.profile.image_192 || user_info.user.profile.image_512

    Rails.logger.tagged("UserCreation") do
      Rails.logger.info({
        event: "slack_user_found",
        slack_id: slack_id,
        email: email,
        username: username_from_slack,
        timezone: timezone,
        avatar: avatar
      }.to_json)
    end

    if email.blank? || !(email =~ URI::MailTo::EMAIL_REGEXP)
      Rails.logger.warn({
        event: "slack_user_missing_or_invalid_email",
        slack_id: slack_id,
        email: email,
        user_info: user_info.to_h
      }.to_json)
      # Honeybadger.notify("Slack email missing??", context: {
      #   slack_id: slack_id,
      #   email: email,
      #   user_info: user_info.to_h
      # })
      raise StandardError, "Slack ID #{slack_id} has an invalid email: #{email.inspect}"
    end

    # Check if user with same email already exists (from OTP login, case-insensitive)
    existing_user = User.where("LOWER(email) = LOWER(?)", email).first
    if existing_user.present?
      Rails.logger.tagged("UserCreation") do
        Rails.logger.info({
          event: "merging_slack_data_into_existing_user",
          existing_user_id: existing_user.id,
          slack_id: slack_id,
          email: email
        }.to_json)
      end

      unless AllowedEmail.allowed?(email)
        raise StandardError, "You do not have access."
      end

      # Merge Slack data into existing user
      existing_user.update!(
        slack_id: slack_id,
        username: username_from_slack.presence || existing_user.display_name,
        timezone_raw: timezone.presence || existing_user.timezone_raw,
        avatar: avatar.presence || existing_user.avatar
      )

      return existing_user
    end

    unless AllowedEmail.allowed?(email)
      raise StandardError, "You do not have access."
    end

    User.create!(
    slack_id: slack_id,
      username: username_from_slack,
      email: email,
      timezone_raw: timezone,
      avatar: avatar,
      is_banned: false,
      referrer_id: referrer_id
    )
  end

  def self.find_or_create_from_email(email, referrer_id: nil)
      # begin
      #   user_info = fetch_slack_user_info_from_email(email)
      # rescue Slack::Web::Api::Errors::UsersNotFound => e
      # Rails.logger.warn("Slack user not found for email #{email}: #{e.message}")

      unless AllowedEmail.allowed?(email)
        raise StandardError, "You do not have access."
      end

      user = User.find_or_create_by!(email: email) do |user|
        user.is_banned = false
        user.referrer_id = referrer_id
      end
      return user
    # end

    if user_info.user.is_bot
      Rails.logger.warn({
        event: "slack_user_is_bot",
        slack_id: slack_id,
        user_info: user_info.to_h
      }.to_json)
      return nil
    end

    slack_id = user_info.user.id
    slack_email = user_info.user.profile.email
    username_from_slack = user_info.user.profile.display_name.presence || user_info.user.profile.real_name
    timezone = user_info.user.tz
    avatar = user_info.user.profile.image_192 || user_info.user.profile.image_512

    unless AllowedEmail.allowed?(slack_email)
      raise StandardError, "You do not have access."
    end

    Rails.logger.tagged("UserCreation") do
      Rails.logger.info({
        event: "slack_user_found",
        slack_id: slack_id,
        email: slack_email,
        username: username_from_slack,
        timezone: timezone,
        avatar: avatar
      }.to_json)
    end

    if slack_email.blank? || !(slack_email =~ URI::MailTo::EMAIL_REGEXP)
      Rails.logger.warn({
        event: "slack_user_missing_or_invalid_email",
        slack_id: slack_id,
        email: slack_email,
        user_info: user_info.to_h
      }.to_json)
      # Honeybadger.notify("Slack email missing??", context: {
      #   slack_id: slack_id,
      #   email: email,
      #   user_info: user_info.to_h
      # })
      raise StandardError, "Slack ID #{slack_id} has an invalid email: #{slack_email.inspect}"
    end

    # Check if user with same slack ID already exists
    existing_user = User.find_by(slack_id: slack_id) || User.find_by(email: slack_email)
    if existing_user.present?
      Rails.logger.tagged("UserCreation") do
        Rails.logger.info({
          event: "slack_user_already_exists",
          existing_user_id: existing_user.id,
          slack_id: slack_id,
          email: slack_email
        }.to_json)
      end

      existing_user.update!(
        slack_id: slack_id,
        username: username_from_slack.presence || existing_user.username,
        timezone_raw: timezone.presence || existing_user.timezone_raw,
        avatar: avatar.presence || existing_user.avatar
      )

      return existing_user
    end

    User.create!(
      slack_id: slack_id,
      username: username_from_slack,
      email: slack_email,
      timezone_raw: timezone,
      avatar: avatar,
      is_banned: false,
      referrer_id: referrer_id
    )
  end

  def self.fetch_slack_user_info_from_email(email)
    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN", nil))

    r = 0
    begin
      client.users_lookupByEmail(email: email)
    rescue Slack::Web::Api::Errors::TooManyRequestsError => e
      if r < 3
        s = e.retry_after
        Rails.logger.warn("Slack API ratelimit, retry in #{s} count#{r + 1}")
        sleep s
        r += 1
        retry
      else
        Rails.logger.error("Slack API ratelimit, max retries on users_lookupByEmail for #{email}.")
        raise
      end
    end
  end

  def self.fetch_slack_user_info(slack_id)
    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN", nil))

    r = 0
    begin
      client.users_info(user: slack_id)
    rescue Slack::Web::Api::Errors::TooManyRequestsError => e
      if r < 3
        s = e.retry_after
        Rails.logger.warn("Slack API ratelimit, retry in #{s} count#{r + 1}")
        sleep s
        r += 1
        retry
      else
        Rails.logger.error("Slack API ratelimit, max retries on #{slack_id}.")
        # Honeybadger.notify("Slack API ratelimit, max retries on #{slack_id}.")
        raise
      end
    end
  end

  def link_github_account(installation_id)
    response = GithubHelper.get_installation_token(installation_id)

    if response.nil?
      Rails.logger.error("GitHub OAuth error: #{response.body}")
      raise StandardError, "Failed to authenticate with GitHub: #{response.body}"
      return
    end

    update!(github_installation_id: installation_id)
    refresh_github_installation!
    refresh_profile!
  end

  def refresh_profile!
    Rails.logger.tagged("ProfileRefresh") do
      Rails.logger.info({
        event: "refreshing_profile_data",
        user_id: id,
        slack_id: slack_id
      }.to_json)
    end

    refresh_github_profile!

    unless slack_user?
      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.info({
          event: "profile_refresh_no_slack",
          user_id: id
        }.to_json)
      end
      return
    end

    user_info = User.fetch_slack_user_info(slack_id)

    new_username = user_info.user.profile.display_name.presence || user_info.user.profile.real_name
    new_email = user_info.user.profile.email
    new_timezone = user_info.user.tz
    new_avatar = user_info.user.profile.image_original.presence || user_info.user.profile.image_512
    new_is_mcg = !!user_info.user.is_restricted

    changes = {}
    changes[:username] = { from: username, to: new_username } if username != new_username
    changes[:email] = { from: email, to: new_email } if email != new_email
    changes[:timezone_raw] = { from: timezone, to: new_timezone } if timezone != new_timezone
    changes[:avatar] = { from: avatar, to: new_avatar } if avatar != new_avatar
    changes[:is_mcg] = { from: is_mcg, to: new_is_mcg } if is_mcg != new_is_mcg

    if changes.any?
      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.info({
          event: "profile_changes_detected",
          user_id: id,
          slack_id: slack_id,
          changes: changes
        }.to_json)
      end

      update!(
        username: new_username,
        email: new_email,
        timezone_raw: new_timezone,
        avatar: new_avatar,
        is_mcg: new_is_mcg
      )

      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.info({
          event: "profile_refresh_success",
          user_id: id,
          slack_id: slack_id
        }.to_json)
      end
    else
      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.debug({
          event: "profile_refresh_no_change",
          user_id: id,
          slack_id: slack_id
        }.to_json)
      end
    end
  rescue StandardError => e
    Rails.logger.tagged("ProfileRefresh") do
      Rails.logger.error({
        event: "profile_refresh_failed",
        user_id: id,
        slack_id: slack_id,
        error: e.message
      }.to_json)
    end

    # Honeybadger.notify(e, context: { user_id: id, slack_id: slack_id })
  end

  def refresh_github_profile!
    unless github_user?
      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.info({
          event: "profile_refresh_no_github",
          user_id: id
        }.to_json)
      end
      return
    end

    response = fetch_github("/app/installations/#{github_installation_id}", jwt: true)

    if response.status == 401
      Rails.logger.tagged("ProfileRefresh") do
        Rails.logger.warn({
          event: "github_token_invalid",
          user_id: id
        }.to_json)
      end
      invalidate_github_installation!
      return
    end

    result = JSON.parse(response.body)

    update!(github_username: result.dig("account", "login")) if result.dig("account", "login").present?
  end

  def follow(project)
    followed_projects << project unless following?(project)
  end

  def unfollow(project)
    followed_projects.delete(project)
  end

  def following?(project)
    followed_projects.include?(project)
  end

  def slack_user?
    slack_id.present? && !slack_id.blank?
  end

  def github_user?
    github_installation_id.present? && !github_installation_id.blank?
  end

  def tasks
    task_list || create_task_list!
  end

  def invite_to_slack!
    xoxc = ENV.fetch("SLACK_XOXC", nil)
    xoxd = ENV.fetch("SLACK_XOXD", nil)
    channels = ENV.fetch("SLACK_CHANNELS", "").split(",").map(&:strip).reject(&:blank?)

    payload = {
      token: xoxc,
      email: email,
      invites: [
        {
          email: email,
          type: "restricted",
          mode: "manual"
        }
      ],
      team_id: "T0266FRGM",
      restricted: false,
      extra_message: "Join the Hack Club Slack to chat with other Blueprint users!",
      channels: channels
    }

    Rails.logger.tagged("SlackInvite") do
      Rails.logger.info({ event: "inviting_user", user_id: id, email: email, channels_count: channels.size }.to_json)
    end

    response = Faraday.post("https://slack.com/api/users.admin.inviteBulk") do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{xoxc}"
      req.headers["Cookie"] = "d=#{xoxd}"
      req.body = JSON.generate(payload)
    end

    result = JSON.parse(response.body) rescue { "ok" => false, "error" => "invalid_json" }

    unless response.status == 200 && result["ok"] != false && result["invites"]&.first["ok"] != false
      Rails.logger.tagged("SlackInvite") do
        Rails.logger.error({ event: "invite_failed", user_id: id, email: email, status: response.status, body: response.body }.to_json)
      end
      raise StandardError, "Slack invite failed: status=#{response.status} body=#{response.body}"
    end

    Rails.logger.tagged("SlackInvite") do
      Rails.logger.info({ event: "invite_enqueued_followup", user_id: id, email: email, response: result }.to_json)
    end

    SlackInviteFinalizeJob.perform_later(id)

    result
  end

  def finalize_slack_invite!
    begin
      user_info = nil
      retries = 0
      max_retries = 10
      delay = 5
      begin
        user_info = User.fetch_slack_user_info_from_email(email)
      rescue Slack::Web::Api::Errors::UsersNotFound
        if retries < max_retries
          Rails.logger.info("Slack user not found for #{email}, waiting #{delay}s and retrying (#{retries + 1}/#{max_retries})")
          sleep delay
          retries += 1
          retry
        else
          raise
        end
      end
    rescue StandardError => e
      Rails.logger.tagged("SlackInvite") do
        Rails.logger.error({ event: "no_slack_user_after_invite", user_id: id, email: email, error: e.message }.to_json)
      end
      return
    end

    update!(slack_id: user_info.user.id)
    refresh_profile!

    Rails.logger.tagged("SlackInvite") do
      Rails.logger.info({ event: "invite_success", user_id: id, email: email }.to_json)
    end
  end

  def check_github_repo(org, repo_name, project_id: nil)
    puts "Checking GitHub repo #{org}/#{repo_name} for user #{id} (#{github_username})"
    unless github_user?
      Rails.logger.tagged("GitHubFetch") do
        Rails.logger.info({
          event: "fetch_no_github",
          user_id: id
        }.to_json)
      end
      return false
    end

    response = fetch_github("/repos/#{org}/#{repo_name}/installation", jwt: true)

    if response.status == 404 || response.status == 301
      return { ok: false, error: "You need to allow Blueprint access to this repo. Please configure GitHub." }
    end

    data = JSON.parse(response.body)

    can_push = data["permissions"]["contents"] == "write"

    unless can_push
      return { ok: false, error: "You need to allow Blueprint access to this repo. Please configure GitHub." }
    end

    normalized = Project.normalize_repo_link("#{org}/#{repo_name}", github_username)

    # Ensure this repo isn't already linked to another project
    in_use = if project_id.present?
      Project.where(repo_link: normalized, is_deleted: false).where.not(id: project_id).exists?
    else
      Project.where(repo_link: normalized, is_deleted: false).exists?
    end

    if in_use
      { ok: false, error: "This repo is already linked to another project" }
    else
      { ok: true, can_push: can_push }
    end
  end

  def fetch_github(path, method: :get, check_token: true, get_all: false, jwt: false, params: {}, data: {}, headers: {})
    unless github_user?
      Rails.logger.tagged("GitHubFetch") do
        Rails.logger.info({
          event: "fetch_no_github",
          user_id: id
        }.to_json)
      end
      raise StandardError, "No GitHub account linked"
    end

    headers = {
      "Authorization" => jwt ? "Bearer #{GithubHelper.generate_jwt}" : "Bearer #{github_access_token}",
      "X-GitHub-Api-Version" => "2022-11-28",
      "Accept" => "application/vnd.github+json"
    }.merge(headers)

    base_url = path.start_with?("http") ? path : "https://api.github.com#{path}"

    response = case method
    when :get
      Faraday.get(base_url, params.presence, headers)
    when :post
      url = params.present? ? "#{base_url}?#{params.to_query}" : base_url
      Faraday.post(url, data.to_json, headers)
    when :put
      url = params.present? ? "#{base_url}?#{params.to_query}" : base_url
      Faraday.put(url, data.to_json, headers)
    when :patch
      url = params.present? ? "#{base_url}?#{params.to_query}" : base_url
      Faraday.patch(url, data.to_json, headers)
    when :delete
      url = params.present? ? "#{base_url}?#{params.to_query}" : base_url
      Faraday.delete(url, nil, headers)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end

    if check_token && response.status == 401
      Rails.logger.tagged("GitHubFetch") do
        Rails.logger.warn({ event: "fetch_401", user_id: id }.to_json)
      end
      invalidate_github_installation!
    end

    response
  end

  def display_name
    if username.present?
      username
    elsif email.present?
      local = email.split("@").first
      if local.blank?
        "User#{id}"
      elsif local.length <= 5
        local
      else
        "#{local[0]}**#{local[-2]}#{local[-1]}"
      end
    else
      "User#{id}"
    end
  end

  def tickets
    build_review_tickets = received_build_reviews
      .approved
      .where(invalidated: false)
      .sum { |br| br.tickets_awarded }

    manual_adjustments = manual_ticket_adjustments.sum(:adjustment)

    shop_order_costs = shop_orders
      .where.not(state: :rejected)
      .sum { |order| (order.frozen_unit_ticket_cost || 0) * (order.quantity || 0) }

    build_review_tickets + manual_adjustments - shop_order_costs
  end

  def follow_project!(project)
    followed_projects << project unless following?(project)
  end

  def unfollow_project!(project)
    followed_projects.destroy(project)
  end

  def avatar_url
    avatar || "https://hc-cdn.hel1.your-objectstorage.com/s/v3/c283ae01214b9052480f1e216e43dbe09a424048_image.png"
  end

  def update_timezone(new_timezone)
    return false if new_timezone.blank?

    # Validate that the timezone is a valid timezone using ActiveSupport::TimeZone
    begin
      ActiveSupport::TimeZone.new(new_timezone)
      self.timezone_raw = new_timezone
      save
    rescue ArgumentError
      errors.add(:timezone_raw, "is not a valid timezone")
      false
    end
  end

  def timezone
    @timezone ||= timezone_raw ? ActiveSupport::TimeZone.new(timezone_raw) : nil
  end

  # Clear cached timezone when raw timezone changes
  def timezone_raw=(value)
    @timezone = nil
    super(value)
  end

  def github_access_token
    if github_installation_id.present? && !github_installation_id.blank?
      cache_key = "github_access_token_#{id}_#{github_installation_id}"

      cached_response = Rails.cache.read(cache_key)
      if cached_response.present?
        return cached_response["token"]
      end

      response = GithubHelper.get_installation_token(github_installation_id)

      # Invalid installation id
      if response.nil?
        Rails.logger.tagged("GitHubFetch") do
          Rails.logger.warn({ event: "fetch_401", user_id: id }.to_json)
        end
        invalidate_github_installation!
        return
      end

      # Cache the full response until 5 minutes before expiration
      expires_at = Time.parse(response["expires_at"])
      cache_expires_at = expires_at - 5.minutes
      cache_ttl = cache_expires_at - Time.current

      if cache_ttl > 0
        Rails.cache.write(cache_key, response, expires_in: cache_ttl)
      end

      response["token"]
    else
      nil
    end
  end

  def invalidate_github_installation!
    Rails.cache.delete("github_access_token_#{id}_#{github_installation_id}")
    update!(github_installation_id: nil)
  end

  def refresh_github_installation!
    Rails.cache.delete("github_access_token_#{id}_#{github_installation_id}")
  end

  # Returns the earliest non-null utm_source for this user based on ahoy_visits
  # It looks up visits that share the same visitor_token as any visit for this user
  def earliest_ref
    ahoy_visits = Class.new(ActiveRecord::Base) { self.table_name = "ahoy_visits" }

    # Find visitor_tokens associated with this user
    visitor_tokens = ahoy_visits.where(user_id: id).distinct.pluck(:visitor_token)
    return nil if visitor_tokens.blank?

    # Find the earliest visit across those visitor_tokens with a non-null utm_source
    visit = ahoy_visits
      .where(visitor_token: visitor_tokens)
      .where.not(utm_source: [ nil, "" ])
      .order(:started_at)
      .limit(1)
      .first

    visit&.utm_source
  end

  def eligible_referral_count
    User.where(referrer_id: id).where.not(slack_id: [ nil, "" ]).where(is_mcg: false).count
  end

  def eligible_referral_count_range(start_datetime, end_datetime)
    User.where(referrer_id: id)
        .where.not(slack_id: [ nil, "" ])
        .where(is_mcg: false)
        .where(created_at: start_datetime..end_datetime)
        .count
  end

  def identity_vault_oauth_link(callback_url, state: nil)
    if ENV["BYPASS_IDV"] == "true"
      return idv_callback_url
    end
    IdentityVaultService.authorize_url(callback_url, {
                                         prefill: {
                                           email: email
                                         }
                                       }, state: state)
  end

  def link_identity_vault_callback(callback_url, code)
    return if ENV["BYPASS_IDV"] == "true"

    code_response = IdentityVaultService.exchange_token(callback_url, code)

    access_token = code_response[:access_token]

    idv_data = fetch_idv(access_token)
    identity_vault_id = idv_data.dig(:identity, :id)

    # Ensure no other user has this identity_vault_id linked already
    if User.where.not(id:).exists?(identity_vault_id:)
      raise StandardError, "Another user already has this identity linked."
    end

    addresses = idv_data.dig(:identity, :addresses) || []
    primary_address = addresses.find { |a| a[:primary] } || addresses.first || {}

    update!(
      identity_vault_access_token: access_token,
      identity_vault_id:,
      ysws_verified: idv_data.dig(:identity,
                                  :verification_status) == "verified" && idv_data.dig(:identity, :ysws_eligible),
      idv_country: primary_address.dig(:country)
    )
  end

  def fetch_idv(access_token = nil)
    if ENV["BYPASS_IDV"] == "true"
      return {}
    end
    IdentityVaultService.me(access_token || identity_vault_access_token)
  end

  def idv_linked?
    if ENV["BYPASS_IDV"] == "true"
      return true
    end
    identity_vault_access_token.present?
  end

  def refresh_idv_data!
    if ENV["BYPASS_IDV"] == "true"
      update!(ysws_verified: true)
    end

    return unless idv_linked?
    return if ysws_verified

    idv_data = fetch_idv
    addresses = idv_data.dig(:identity, :addresses) || []
    primary_address = addresses.find { |a| a[:primary] } || addresses.first || {}

    update!(
      ysws_verified: idv_data.dig(:identity,
                                  :verification_status) == "verified" && idv_data.dig(:identity, :ysws_eligible),
      idv_country: primary_address.dig(:country)
    )
  end

  def advance_projects_after_idv!
    return unless ysws_verified

    projects.where(review_status: "awaiting_idv").find_each do |project|
      begin
        project.passed_idv!
      rescue => e
        Sentry.capture_exception(e)
      end
    end
  end

  def reviewer_perms?
    admin? || reviewer?
  end

  def fulfiller_perms?
    admin? || fulfiller?
  end

  def special_perms?
    admin? || reviewer? || fulfiller?
  end

  def is_adult?
    birthday.present? && birthday < 19.years.ago
  end

  private

  def sync_to_gorse
    GorseSyncUserJob.perform_later(id)
  end

  def delete_from_gorse
    GorseService.delete_user(self)
  rescue => e
    Rails.logger.error("Failed to delete user #{id} from Gorse: #{e.message}")
    Sentry.capture_exception(e)
  end
end
