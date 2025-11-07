# == Schema Information
#
# Table name: projects
#
#  id                     :bigint           not null, primary key
#  approved_funding_cents :integer
#  approved_tier          :integer
#  demo_link              :string
#  description            :text
#  funding_needed_cents   :integer          default(0), not null
#  hackatime_project_keys :string           default([]), is an Array
#  is_deleted             :boolean          default(FALSE)
#  journal_entries_count  :integer          default(0), not null
#  needs_funding          :boolean          default(TRUE)
#  needs_soldering_iron   :boolean          default(FALSE), not null
#  print_legion           :boolean          default(FALSE), not null
#  project_type           :string
#  readme_link            :string
#  repo_link              :string
#  review_status          :string
#  skip_gh_sync           :boolean          default(FALSE)
#  tier                   :integer
#  title                  :string
#  views_count            :integer          default(0), not null
#  viral                  :boolean          default(FALSE), not null
#  ysws                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_projects_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Project < ApplicationRecord
  include ActionView::Helpers::TextHelper

  attr_accessor :preloaded_view_count, :preloaded_follower_count

  belongs_to :user
  has_many :journal_entries, dependent: :destroy, counter_cache: true
  has_one :latest_journal_entry, -> { order(created_at: :desc) }, class_name: "JournalEntry"
  has_many :timeline_items, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :followers, through: :follows, source: :user
  has_many :design_reviews, dependent: :destroy
  has_many :build_reviews, dependent: :destroy
  has_many :project_grants, dependent: :destroy
  has_many :kudos, dependent: :destroy

  def self.airtable_sync_table_id
    "tblwQanyNgONPvBdL"
  end

  def self.airtable_sync_sync_id
    "clZF1lJC"
  end

  def self.airtable_sync_field_mappings
    {
      "Project ID" => :id,
      "Project Name" => :title,
      "Demo Link" => :demo_link,
      "Description" => :description,
      "Funding Needed Cents" => :funding_needed_cents,
      "Is Deleted" => :is_deleted,
      "Needs Funding" => :needs_funding,
      "Print Legion" => :print_legion,
      "Readme Link" => :readme_link,
      "Review Status" => :review_status,
      "Tier" => :tier,
      "Title" => :title,
      "Views" => :views_count,
      "YSWS" => :ysws,
      "Created At" => :created_at,
      "Updated At" => :updated_at,
      "User ID" => :user_id,
      "Followers" => lambda { |project| project.followers.pluck(:id).join(",") }
    }
  end

  # Enums
  enum :project_type, {
    custom: "custom",
    led: "led"
  }

  enum :review_status, {
    awaiting_idv: "awaiting_idv",
    design_pending: "design_pending",
    design_approved: "design_approved",
    design_needs_revision: "design_needs_revision",
    design_rejected: "design_rejected",
    build_pending: "build_pending",
    build_approved: "build_approved",
    build_needs_revision: "build_needs_revision",
    build_rejected: "build_rejected"
  }

  enum :tier, {
    "1" => 1,
    "2" => 2,
    "3" => 3,
    "4" => 4,
    "5" => 5
  }, prefix: true

  validates :title, presence: true
  validates :funding_needed_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :funding_needed_within_tier_max
  has_one_attached :banner
  has_one_attached :demo_picture
  has_many_attached :cart_screenshots

  validates :banner, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                     size: { less_than: 5.megabytes }
  validates :demo_picture, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                           size: { less_than: 5.megabytes }
  validates :cart_screenshots, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                               size: { less_than: 10.megabytes }

  has_paper_trail
  include PaperTrailHelper

  def display_banner
    return banner.blob if banner.attached?

    if latest_journal_entry&.content.present?
      image_match = latest_journal_entry.content.match(/!\[[^\]]*\]\(([^)]+)\)/)
      if image_match
        image_url = image_match[1]
        blob_match = image_url.match(/blobs\/[^\/]+\/([^\/\?]+)/)
        return ActiveStorage::Blob.find_signed(blob_match[1]) if blob_match
      end
    end

    nil
  end

  # Order projects by most recent journal entry; fall back to project creation
  scope :order_by_recent_journal, -> {
    left_joins(:journal_entries)
      .select("projects.*, COALESCE(MAX(journal_entries.created_at), projects.created_at) AS last_activity_at")
      .group("projects.id")
      .order(Arel.sql("last_activity_at DESC"))
  }

  before_validation :normalize_repo_link
  before_validation :set_funding_needed_cents_to_zero_if_no_funding
  after_update_commit :sync_github_journal!, if: -> { saved_change_to_repo_link? && repo_link.present? }
  after_update :invalidate_design_reviews_on_resubmit, if: -> { saved_change_to_review_status? && design_pending? }
  after_update :invalidate_build_reviews_on_resubmit, if: -> { saved_change_to_review_status? && build_pending? }
  after_update :approve_design!, if: -> { saved_change_to_review_status? && design_approved? }
  after_update :approve_build!, if: -> { saved_change_to_review_status? && build_approved? }
  after_update :dm_status!, if: -> { saved_change_to_review_status? }
  after_commit :sync_to_gorse, on: [ :create, :update ]
  after_commit :delete_from_gorse, on: :destroy
  after_commit :sync_journal_entries_to_gorse, if: -> { saved_change_to_is_deleted? }

  def self.parse_repo(repo)
    # Supports:
    # - Full URL (http/https): https://github.com/org/repo[.git][/...]
    # - Full URL (any host): https://gitlab.com/org/repo[.git][/...]
    # - SSH: git@github.com:org/repo[.git] or git@gitlab.com:org/repo[.git]
    # - Bare: org/repo
    # - Repo only: repo (org inferred by caller)
    repo = repo.to_s.strip
    return nil if repo.blank?

    # Try to parse as HTTP(S) URL
    begin
      uri = URI.parse(repo)
      if uri && %w[http https].include?(uri.scheme) && uri.host.present?
        host = uri.host.downcase.sub(/\Awww\./, "")
        parts = uri.path.to_s.split("/").reject(&:blank?)

        if host == "github.com" && parts.size >= 2
          # GitHub URL - extract org and repo
          org = parts[0]
          name = parts[1].sub(/\.git\z/i, "")
          return { org: org, repo_name: name }
        elsif parts.size >= 2
          # Non-GitHub URL - preserve full URL without credentials, query, or fragment
          sanitized = "#{uri.scheme}://#{host}#{uri.path}"
          sanitized = sanitized.sub(/\.git\z/i, "").sub(%r{/+\z}, "")
          return { full_url: sanitized }
        else
          return nil
        end
      end
    rescue URI::InvalidURIError
      # Not a valid URI, continue to other patterns
    end

    # Generic SSH pattern: git@host:org/repo[.git]
    if m = repo.match(%r{\Agit@([^:]+):([^/]+)/([^/]+?)(?:\.git)?\z}i)
      host = m[1].downcase.sub(/\Awww\./, "")
      org = m[2]
      name = m[3]
      if host == "github.com"
        return { org: org, repo_name: name }
      else
        # Non-GitHub SSH - preserve as-is without .git
        return { full_url: repo.sub(/\.git\z/i, "") }
      end
    end

    # GitHub-specific short forms
    case repo
    when %r{\Agithub\.com/([^/]+)/([^/]+)}i
      org = Regexp.last_match(1)
      repo_name = Regexp.last_match(2).sub(/\.git\z/i, "")
      return { org: org, repo_name: repo_name }
    when %r{\A([^/]+)/([^/]+)\z}
      org = Regexp.last_match(1)
      repo_name = Regexp.last_match(2)
      return { org: org, repo_name: repo_name }
    when %r{\A([\w.-]+)\z}
      return { org: nil, repo_name: repo }
    end

    nil
  end

  def self.normalize_repo_link(raw, username)
    stripped = raw.to_s.strip
    return if stripped.blank?

    parsed = Project.parse_repo(stripped)
    return unless parsed

    # If it's a full URL to any host, preserve it
    return parsed[:full_url] if parsed[:full_url]

    org = parsed[:org] || username
    repo = parsed[:repo_name]

    return if org.blank? || repo.blank?

    "https://github.com/#{org}/#{repo}"
  end

  def generate_timeline(reverse: false)
    timeline = []

    timeline << { type: :creation, date: created_at }

    journal_entries.order(created_at: :asc).each do |entry|
      timeline << { type: :journal, date: entry.created_at, entry: entry }
    end

    kudos.order(created_at: :asc).each do |kudo|
      timeline << { type: :kudo, date: kudo.created_at, kudo: kudo }
    end

    ship_design_events = attribute_updated_event(object: self, attribute: :review_status, after: "design_pending", all: true)
    ship_build_events = attribute_updated_event(object: self, attribute: :review_status, after: "build_pending", all: true)
    user_ids = (ship_design_events + ship_build_events).map { |e| e[:whodunnit] }.compact.uniq
    user_ids += kudos.pluck(:user_id).map(&:to_s)

    all_design_reviews = design_reviews.where(result: %w[returned rejected])
                                .or(design_reviews.where(result: "approved", admin_review: true))
                                .order(created_at: :asc)
    return_design_events = []
    reject_design_events = []
    approve_design_groups = []
    previous_result = nil

    all_design_reviews.each do |review|
      user_ids << review.reviewer_id.to_s

      if review.result == "returned"
        return_design_events << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override, grant_override_cents: review.grant_override_cents }
      elsif review.result == "rejected"
        reject_design_events << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override, grant_override_cents: review.grant_override_cents }
      elsif review.result == "approved"
        if previous_result != "approved"
          approve_design_groups << { date: review.created_at, reviews: [] }
        end
        approve_design_groups.last[:reviews] << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override, grant_override_cents: review.grant_override_cents, admin_review: review.admin_review }
      end

      previous_result = review.result
    end

    all_build_reviews = build_reviews.where(result: %w[returned rejected])
                                .or(build_reviews.where(result: "approved", admin_review: true))
                                .order(created_at: :asc)
    return_build_events = []
    reject_build_events = []
    approve_build_groups = []
    previous_result = nil

    all_build_reviews.each do |review|
      user_ids << review.reviewer_id.to_s

      if review.result == "returned"
        return_build_events << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override }
      elsif review.result == "rejected"
        reject_build_events << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override }
      elsif review.result == "approved"
        if previous_result != "approved"
          approve_build_groups << { date: review.created_at, reviews: [] }
        end
        approve_build_groups.last[:reviews] << { date: review.created_at, user_id: review.reviewer_id, feedback: review.feedback, tier_override: review.tier_override, admin_review: review.admin_review }
      end

      previous_result = review.result
    end

    user_ids.uniq!
    users = User.where(id: user_ids).index_by { |u| u.id.to_s }

    ship_design_events.each do |event|
      user = users[event[:whodunnit].to_s]
      timeline << { type: :ship, date: event[:timestamp], user: user }
    end

    ship_build_events.each do |event|
      user = users[event[:whodunnit].to_s]
      timeline << { type: :ship, date: event[:timestamp], user: user }
    end

    return_design_events.each do |event|
      user = users[event[:user_id].to_s]
      timeline << { type: :return_design, date: event[:date], user: user, feedback: event[:feedback], tier_override: event[:tier_override], grant_override_cents: event[:grant_override_cents] }
    end

    reject_design_events.each do |event|
      user = users[event[:user_id].to_s]
      timeline << { type: :reject_design, date: event[:date], user: user, feedback: event[:feedback], tier_override: event[:tier_override], grant_override_cents: event[:grant_override_cents] }
    end

    approve_design_groups.each do |group|
      reviews_with_users = group[:reviews].map do |r|
        r.merge(user: users[r[:user_id].to_s])
      end
      timeline << { type: :approve_design, date: group[:date], reviews: reviews_with_users }
    end

    return_build_events.each do |event|
      user = users[event[:user_id].to_s]
      timeline << { type: :return_build, date: event[:date], user: user, feedback: event[:feedback], tier_override: event[:tier_override] }
    end

    reject_build_events.each do |event|
      user = users[event[:user_id].to_s]
      timeline << { type: :reject_build, date: event[:date], user: user, feedback: event[:feedback], tier_override: event[:tier_override] }
    end

    approve_build_groups.each do |group|
      reviews_with_users = group[:reviews].map do |r|
        r.merge(user: users[r[:user_id].to_s])
      end
      timeline << { type: :approve_build, date: group[:date], reviews: reviews_with_users }
    end

    sorted_timeline = timeline.sort_by { |e| e[:date] }
    reverse ? sorted_timeline.reverse : sorted_timeline
  end

  def bom_file_url
    return nil if repo_link.blank?
    parsed = parse_repo
    return nil unless parsed && parsed[:org].present? && parsed[:repo_name].present?
    "https://github.com/#{parsed[:org]}/#{parsed[:repo_name]}/blob/HEAD/bom.csv"
  end

  def bom_file_exists?
    return false if repo_link.blank?
    parsed = parse_repo
    return false unless parsed && parsed[:org].present? && parsed[:repo_name].present?

    paths = [
      "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/bom.csv",
      "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/BOM.csv",
      "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/Bom.csv"
    ]

    paths.each do |path|
      response = if user&.github_user?
        user.fetch_github(path, check_token: true)
      else
        Faraday.get("https://api.github.com#{path}", nil, {
          "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28"
        })
      end

      if response.status == 200
        return true
      end
    end

    false
  rescue StandardError
    false
  end

  def readme_file_url
    return nil if repo_link.blank?
    parsed = parse_repo
    return nil unless parsed && parsed[:org].present? && parsed[:repo_name].present?
    "https://github.com/#{parsed[:org]}/#{parsed[:repo_name]}/blob/HEAD/README.md"
  end

  def readme_file_exists?
    return false if repo_link.blank?
    parsed = parse_repo
    return false unless parsed && parsed[:org].present? && parsed[:repo_name].present?

    path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/README.md"

    response = if user&.github_user?
      user.fetch_github(path, check_token: true)
    else
      Faraday.get("https://api.github.com#{path}", nil, {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28"
      })
    end

    response.status == 200
  rescue StandardError
    false
  end

  def generate_journal(include_time)
    include_time ||= false
    timezone = user.timezone_raw.presence || "UTC"

    contents =
    <<~EOS
    <!--
      ===================    !!READ THIS NOTICE!!   ====================
      DO NOT edit this file manually. Your changes WILL BE OVERWRITTEN!
      This journal is auto generated and updated by Hack Club Blueprint.
      To edit this file, please edit your journal entries on Blueprint.
      ==================================================================
    -->

    EOS

    journals = journal_entries.order(created_at: :asc)

    day_counts = journals.group_by { |e| e.created_at.in_time_zone(timezone).to_date }.transform_values(&:size)
    hour_counts = journals.group_by { |e| [ e.created_at.in_time_zone(timezone).to_date, e.created_at.in_time_zone(timezone).hour ] }.transform_values(&:size)

    journals.each do |entry|
      t = entry.created_at.in_time_zone(timezone)
      header_ts = if day_counts[t.to_date] && day_counts[t.to_date] > 1
        if hour_counts[[ t.to_date, t.hour ]] && hour_counts[[ t.to_date, t.hour ]] > 1
          t.strftime("%-m/%-d/%Y %-I:%M %p")
        else
          t.strftime("%-m/%-d/%Y %-I %p")
        end
      else
        t.strftime("%-m/%-d/%Y")
      end

      contents += "## #{header_ts}#{entry.summary.present? ? " - #{entry.summary}" : ""}  \n\n"
      if include_time
        contents += "_Time spent: #{(entry.duration_seconds / 3600.0).round(2)}h_  \n\n"
      end
      contents += "#{replace_local_images(entry.content)}  \n\n"
    end

    contents
  end

  def sync_github_journal!
    return true

    return unless user&.github_user? && repo_link.present?
    return if skip_gh_sync?

    # Only sync if it's a GitHub repo
    parsed = parse_repo
    return unless parsed && parsed[:org].present? && parsed[:repo_name].present?

    GithubJournalSyncJob.perform_later(id)
  end

  def parse_repo
    return { org: nil, repo: nil } if repo_link.blank?

    Project.parse_repo(repo_link)
  end

  def self.tier_options
      tier_amounts = { 1 => "$0 - $400", 2 => "$0 - $200", 3 => "$0 - $100", 4 => "$0 - $50", 5 => "$0 - $25" }
      Project.tiers.map { |key, value| [ "Tier #{key} (#{tier_amounts[key.to_i]})", value ] }
  end

  def self.tier_options_with_multipliers
    tier_multipliers = { 1 => "1.5x multiplier", 2 => "1.25x multiplier", 3 => "1.1x multiplier", 4 => "1.0x multiplier", 5 => "0.8x multiplier" }
    Project.tiers.map { |key, value| [ "Tier #{key} (#{tier_multipliers[key.to_i]})", value ] }
  end

  def self.tier_max_cents
    { 1 => 40000, 2 => 20000, 3 => 10000, 4 => 5000, 5 => 2500 }
  end

  def tier_max_cents
    return 0 unless tier.present?
    Project.tier_max_cents[tier] || 0
  end

  def report_grant_given!(amount_cents, tier)
    ProjectGrant.create!(project: self, grant_cents: amount_cents, tier: tier)
    update!(approved_funding_cents: amount_cents, approved_tier: tier)
  end

  def ship!(design: nil)
    unless can_ship?
      throw "Project is already shipped!"
    end

    if user.ysws_verified.nil? || user.ysws_verified == false
      update!(review_status: :awaiting_idv)
      return
    end

    # Check if project has an approved admin design review (one-way gate: design -> build)
    has_approved_design = design_reviews.where(result: :approved, invalidated: false, admin_review: true).exists?

    # Once build is approved OR design is approved, always go to build (one-way gate)
    if build_approved? || has_approved_design
      update!(review_status: :build_pending)
    elsif design == true
      update!(review_status: :design_pending)
    elsif design == false
      update!(review_status: :build_pending)
    else
      # No explicit design param and no approved review - use needs_funding
      update!(review_status: needs_funding? ? :design_pending : :build_pending)
    end

    user.update(is_pro: true) unless user.is_pro?
  end

  def passed_idv!
    ship!
  end

  def under_review?
    design_pending? || build_pending?
  end

  def rejected?
    design_rejected? || build_rejected?
  end

  def can_edit?
    !under_review? && !rejected? && !awaiting_idv?
  end

  def can_ship?
    review_status.nil? || design_needs_revision? || build_needs_revision? || awaiting_idv? || design_approved? || build_approved?
  end

  def followed_by?(user)
    user.followed_projects.include?(self)
  end

  def follower_count
    followers.count
  end

  def view_count
    views_count
  end

  def self.view_counts_for(project_ids)
    return {} if project_ids.blank?
    Project.where(id: project_ids).pluck(:id, :views_count).to_h
  end

  def self.follower_counts_for(project_ids)
    return {} if project_ids.blank?
    Follow.where(project_id: project_ids).group(:project_id).count
  end

  def dm_status!
    unless user&.slack_id.present?
      Rails.logger.tagged("Project##{id}DM") do
        Rails.logger.warn "User #{user&.id} has no slack_id"
      end
      return
    end

    msg = "Hey <@#{user.slack_id}>!\n\n"

    if awaiting_idv?
      msg += "Your Blueprint project *#{title}* is almost ready to be reviewed! But before we can review your project, you need to verify your identity.\n\nHack Club has given out over $1M in grants to teens like you, and with that comes a lot of adults trying to slip in.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/auth/idv|Click here to verify your identity>\n\n"
    elsif design_pending?
      msg += "Your Blueprint project *#{title}* is currently waiting for a design review. An inspector will take a look at it soon!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    elsif build_pending?
      msg += "Your Blueprint project *#{title}* is currently waiting for a build review. An inspector will take a look at it soon!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    elsif design_needs_revision?
      review = design_reviews.where(result: "returned", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved. Here's some feedback from your inspector, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Recommended tier:* #{review.tier_override}\n\n" if review.tier_override.present?
        msg += "*Recommended funding:* $#{'%.2f' % (review.grant_override_cents / 100.0)}\n\n" if review.grant_override_cents.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif design_rejected?
      review = design_reviews.where(result: "rejected", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* has been rejected. You won't be able to submit again.Here's some feedback from your inspector, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Recommended tier:* #{review.tier_override}\n\n" if review.tier_override.present?
        msg += "*Grant to expect:* $#{'%.2f' % (review.grant_override_cents / 100.0)}\n\n" if review.grant_override_cents.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* has been rejected. You won't be able to submit again.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif design_approved?
      msg += "Your Blueprint project *#{title}* has passed the design review! You should receive an email from HCB about your grant in a few business days.\n\n"

      msg += "*Grant approved:* $#{'%.2f' % (approved_funding_cents / 100.0)}\n\n" if approved_funding_cents.present?
      msg += "*Tier approved:* #{approved_tier}\n\n" if approved_tier.present?

      admin_review = design_reviews.where(admin_review: true, result: "approved", invalidated: false).order(created_at: :desc).first
      if admin_review && admin_review.feedback.present? && admin_review.reviewer&.slack_id.present?
        msg += "<@#{admin_review.reviewer.slack_id}> left the following notes:\n\n#{admin_review.feedback}\n\n"
      end
      msg += "You can now start building your project and ship it for tickets when it's ready.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    elsif build_needs_revision?
      review = build_reviews.where(result: "returned", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved for tickets. Here's some feedback from your inspector, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Tier:* #{review.tier_override || review.frozen_tier}\n\n" if review.tier_override.present? || review.frozen_tier.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved for tickets.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif build_rejected?
      review = build_reviews.where(result: "rejected", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* has been rejected for tickets. Here's some feedback from your inspector, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Tier:* #{review.tier_override || review.frozen_tier}\n\n" if review.tier_override.present? || review.frozen_tier.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* has been rejected for tickets.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif build_approved?
      msg += "Your Blueprint project *#{title}* has passed the build review! You've been awarded tickets for your work.\n\n"

      # Find the most recent approved review with actual hours (second approvals may have 0)
      review = build_reviews.where(result: "approved", invalidated: false)
                            .order(updated_at: :desc)
                            .detect { |r| r.frozen_duration_seconds.to_i > 0 } ||
               build_reviews.where(result: "approved", invalidated: false)
                            .order(updated_at: :desc)
                            .first

      if review
        tickets = review.tickets_awarded

        msg += "*Total tickets awarded:* #{tickets} tickets\n\n"

        admin_review = build_reviews.where(admin_review: true, result: "approved", invalidated: false).order(created_at: :desc).first
        if admin_review && admin_review.feedback.present? && admin_review.reviewer&.slack_id.present?
          msg += "<@#{admin_review.reviewer.slack_id}> left the following notes:\n\n#{admin_review.feedback}\n\n"
        end
      end
      msg += "Keep building and ship again for more tickets!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    else
      msg += "Your Blueprint project *#{title}* has been updated!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    end

    SlackDmJob.perform_later(user.slack_id, msg)
  end

  def upload_to_airtable!
    begin
      idv_data = user&.fetch_idv || {}
    rescue StandardError => e
      Rails.logger.tagged("Project##{id}Airtable") do
        Rails.logger.error "Failed to fetch IDV data for user #{user&.id}: #{e.message}"
      end
      idv_data ||= {}
    end
    addresses = idv_data.dig(:identity, :addresses) || []
    primary_address = addresses.find { |a| a[:primary] } || addresses.first || {}

    # Check if this is an LED project
    if ysws == "led"
      hours_for_airtable = 5
      reasoning = "This project followed the 555 LED blinker guide. This was a guide that we have used at workshops before and which took students new to hardware a minimum of 5 hours to complete. This project at least meets the standards of a project submitted at this event. - Clay"
    else
      # Calculate total hours from ALL journal entries
      total_hours_logged = journal_entries.sum(:duration_seconds) / 3600.0

      # Get approved reviews
      approved_design_reviews = design_reviews.where(result: "approved", invalidated: false, admin_review: true).order(created_at: :asc)
      approved_build_reviews = build_reviews.where(result: "approved", invalidated: false, admin_review: true).order(created_at: :asc)

      # Calculate total effective hours from all approved reviews (design + build)
      total_effective_hours = 0
      approved_design_reviews.each { |r| total_effective_hours += r.effective_hours }
      approved_build_reviews.each { |r| total_effective_hours += r.effective_hours }

      # Use total effective hours if any reviews exist, otherwise use total logged
      hours_for_airtable = (approved_design_reviews.any? || approved_build_reviews.any?) ? total_effective_hours : total_hours_logged

      reasoning = "This user logged #{total_hours_logged.round(1)} hours across #{pluralize(journal_entries.count, 'journal entry')}.\n\n\n"

      approved_design_reviews.each do |review|
        reasoning += "On #{review.created_at.strftime('%Y-%m-%d')}, #{review.admin_review ? 'Admin' : 'Reviewer'} #{review.reviewer.display_name} (#{review.reviewer.email}) decided \"#{review.result}\" with reason: #{review.reason.present? && !review.reason.empty? ? review.reason : 'no reason'}\n\n\n"
      end

      approved_build_reviews.each do |review|
        reasoning += "On #{review.created_at.strftime('%Y-%m-%d')}, #{review.admin_review ? 'Admin' : 'Reviewer'} #{review.reviewer.display_name} (#{review.reviewer.email}) decided \"#{review.result}\" with reason: #{review.reason.present? && !review.reason.empty? ? review.reason : 'no reason'}\n\n\n"
      end
    end

    # For grants, use design review override if present
    grant = design_reviews.where.not(grant_override_cents: nil).where(invalidated: false, admin_review: true).order(created_at: :desc).first&.grant_override_cents || funding_needed_cents

    fields = {
      "Code URL" => repo_link,
      "Playable URL" => demo_link || repo_link,
      "First Name" => idv_data.dig(:identity, :first_name),
      "Last Name" => idv_data.dig(:identity, :last_name),
      "Email" => user&.email,
      "Screenshot" => (banner.attached? ? [
        {
          "url" => Rails.application.routes.url_helpers.rails_blob_url(banner, host: ENV.fetch("APPLICATION_HOST")),
          "filename" => banner.filename.to_s
        }
      ] : nil),
      "Description" => description,
      "Address (Line 1)" => primary_address.dig(:line_1),
      "Address (Line 2)" => primary_address.dig(:line_2),
      "City" => primary_address.dig(:city),
      "State / Province" => primary_address.dig(:state),
      "Country" => primary_address.dig(:country),
      "ZIP / Postal Code" => primary_address.dig(:postal_code),
      "Birthday" => idv_data.dig(:identity, :birthday),
      "Optional - Override Hours Spent" => hours_for_airtable,
      "Optional - Override Hours Spent Justification" => reasoning,
      "Slack ID" => user&.slack_id,
      "Project Name" => title,
      "Requested Grant Amount" => grant ? (grant / 100.0) : nil,
      "Grant Tier" => tier,
      "Hours Self-Reported" => journal_entries.sum(:duration_seconds) / 3600.0,
      "Checkout Screens" => (cart_screenshots.attached? ? cart_screenshots.map { |s|
        {
          "url" => Rails.application.routes.url_helpers.rails_blob_url(s, host: ENV.fetch("APPLICATION_HOST")),
          "filename" => s.filename.to_s
        }
      } : nil),
      "BP Project ID" => id
    }

    AirtableSync.upload_or_create!(
      "tblRH1aELwmy7rgEU", self, fields
    )
  end

  def sync_to_gorse
    GorseSyncProjectJob.perform_later(id)
  end

  def delete_from_gorse
    GorseService.delete_item(self)
  rescue => e
    Rails.logger.error("Failed to delete project #{id} from Gorse: #{e.message}")
    Sentry.capture_exception(e)
  end

  def sync_journal_entries_to_gorse
    journal_entries.find_each do |entry|
      GorseSyncJournalEntryJob.perform_later(entry.id)
    end
  end

  # @deprecated Use unreviewed_journal_entries instead
  def last_non_invalid_review_at
    [
      design_reviews.where(invalidated: false).maximum(:created_at),
      build_reviews.where(invalidated: false).maximum(:created_at)
    ].compact.max
  end

  # @deprecated Use unreviewed_journal_entries instead
  def last_non_invalid_build_review_at
    build_reviews.where(invalidated: false).maximum(:created_at)
  end

  def unreviewed_journal_entries
    journal_entries.where(review_id: nil)
  end

  def journal_entries_since_last_build_review
    unreviewed_journal_entries
  end

  def hours_since_last_build_review
    unreviewed_journal_entries.sum(:duration_seconds) / 3600.0
  end

  def entries_since_last_build_review_count
    unreviewed_journal_entries.count
  end

  private

  def normalize_repo_link
    normalized = Project.normalize_repo_link(repo_link, user&.github_username)
    self.repo_link = normalized if normalized.present?
  end

  def set_funding_needed_cents_to_zero_if_no_funding
    self.funding_needed_cents = 0 unless needs_funding?
  end

  def funding_needed_within_tier_max
    return unless needs_funding? && tier.present? && funding_needed_cents.present? && funding_needed_cents > 0

    max_cents = tier_max_cents
    if max_cents > 0 && funding_needed_cents > max_cents
      errors.add(:funding_needed_cents, "cannot exceed tier maximum of $#{max_cents / 100.0}")
    end
  end

  def invalidate_design_reviews_on_resubmit
    # Don't invalidate if there's already an approved admin design review (one-way gate)
    return if design_reviews.where(result: "approved", invalidated: false, admin_review: true).exists?

    to_invalidate = design_reviews.pluck(:id)
    design_reviews.where(id: to_invalidate).update_all(invalidated: true)
    JournalEntry.where(project_id: id, review_type: "DesignReview", review_id: to_invalidate).update_all(review_id: nil, review_type: nil)
  end

  def invalidate_build_reviews_on_resubmit
    # Only invalidate non-approved build reviews to preserve journal entry cutoffs for multi-round reviews
    to_invalidate = build_reviews.where.not(result: "approved").pluck(:id)
    build_reviews.where(id: to_invalidate).update_all(invalidated: true)
    JournalEntry.where(project_id: id, review_type: "BuildReview", review_id: to_invalidate).update_all(review_id: nil, review_type: nil)
  end

  def approve_design!
    admin_review = design_reviews.where(admin_review: true, result: "approved", invalidated: false).order(created_at: :desc).first

    update_columns(
      approved_tier: admin_review&.tier_override || tier,
      approved_funding_cents: admin_review&.grant_override_cents || funding_needed_cents
    )

    upload_to_airtable!
  end

  def approve_build!
    # Upload build review data to Airtable
    upload_to_airtable!
  end

  def replace_local_images(content)
    return content if content.blank?

    host = ENV.fetch("APPLICATION_HOST")

    # ![alt text](/user-attachments/...) — preserve alt text and avoid double ")"
    content.gsub!(
      /!\[(.*?)\]\((\/user-attachments\/[\S^)]+)(\s+\"[^\"]*\")?\)/,
      "![\\1](https://#{host}\\2\\3)"
    )

    # src="/user-attachments/..."
    content.gsub!(/src=["'](\/user-attachments\/.*?)(?=["'])/, "src=\"https://#{host}\\1\"")

    content
  end
end
