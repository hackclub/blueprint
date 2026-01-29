# == Schema Information
#
# Table name: projects
#
#  id                          :bigint           not null, primary key
#  approved_funding_cents      :integer
#  approved_tier               :integer
#  approx_hour                 :decimal(3, 1)
#  build_review_claimed_at     :datetime
#  build_slack_message         :string
#  demo_link                   :string
#  description                 :text
#  design_review_claimed_at    :datetime
#  design_slack_message        :string
#  funding_needed_cents        :integer          default(0), not null
#  hackatime_project_keys      :string           default([]), is an Array
#  is_deleted                  :boolean          default(FALSE)
#  journal_entries_count       :integer          default(0), not null
#  needs_funding               :boolean          default(TRUE)
#  needs_soldering_iron        :boolean          default(FALSE), not null
#  print_legion                :boolean          default(FALSE), not null
#  project_type                :string
#  readme_link                 :string
#  repo_link                   :string
#  review_status               :string
#  reviewer_note               :text
#  skip_gh_sync                :boolean          default(FALSE)
#  tier                        :integer
#  title                       :string
#  unlisted                    :boolean          default(FALSE), not null
#  views_count                 :integer          default(0), not null
#  viral                       :boolean          default(FALSE), not null
#  ysws                        :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  build_review_claimed_by_id  :bigint
#  design_review_claimed_by_id :bigint
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_projects_on_build_review_claimed_by_id   (build_review_claimed_by_id)
#  index_projects_on_design_review_claimed_by_id  (design_review_claimed_by_id)
#  index_projects_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_review_claimed_by_id => users.id)
#  fk_rails_...  (design_review_claimed_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class Project < ApplicationRecord
  include ActionView::Helpers::TextHelper

  attr_accessor :preloaded_view_count, :preloaded_follower_count

  belongs_to :user
  belongs_to :design_review_claimed_by, class_name: "User", optional: true
  belongs_to :build_review_claimed_by, class_name: "User", optional: true
  has_many :journal_entries, dependent: :destroy, counter_cache: true
  has_one :latest_journal_entry, -> { order(created_at: :desc) }, class_name: "JournalEntry"
  has_many :timeline_items, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :followers, through: :follows, source: :user
  has_many :design_reviews, dependent: :destroy
  has_many :build_reviews, dependent: :destroy
  has_many :valid_design_reviews, -> { where(invalidated: false) }, class_name: "DesignReview"
  has_many :valid_build_reviews, -> { where(invalidated: false) }, class_name: "BuildReview"
  has_many :project_grants, dependent: :destroy
  has_many :kudos, dependent: :destroy
  has_many :packages, as: :trackable, dependent: :destroy

  def self.airtable_sync_table_id
    "tblwQanyNgONPvBdL"
  end

  def self.airtable_sync_sync_id
    "clZF1lJC"
  end

  def self.airtable_should_batch
    true
  end

  def self.airtable_batch_size
    4000
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
      "Needs Soldering Iron" => :needs_soldering_iron,
      "Followers" => lambda { |project| project.followers.pluck(:id).join(",") },
      "Country" => lambda { |project| project.user&.country }
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
  validates :approx_hour, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 99.9 }, allow_nil: true
  validate :approx_hour_one_decimal
  validate :funding_needed_within_tier_max
  has_one_attached :banner
  has_one_attached :demo_picture do |attachable|
    attachable.variant :web,
      resize_to_limit: [ 2000, 2000 ],
      convert: :webp,
      saver: { quality: 80, strip: true },
      preprocessed: true
  end
  has_many_attached :cart_screenshots

  validates :banner, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                     size: { less_than: 5.megabytes }
  validates :demo_picture, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                           size: { less_than: 5.megabytes }
  validates :cart_screenshots, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                               size: { less_than: 10.megabytes }

  has_paper_trail
  include PaperTrailHelper

  WEB_IMAGE_VARIANT_OPTIONS = {
    resize_to_limit: [ 2000, 2000 ],
    convert: :webp,
    saver: { quality: 80, strip: true }
  }.freeze

  def display_banner
    blob = display_banner_blob
    return unless blob&.image?
    return blob if blob.content_type == "image/svg+xml"

    blob.variant(WEB_IMAGE_VARIANT_OPTIONS)
  end

  def display_banner_blob
    demo_version = demo_picture_attachment&.id || 0
    journal_id = latest_journal_entry&.id || 0
    journal_version = latest_journal_entry&.updated_at&.to_i || 0
    cache_key = "project_banner_blob/#{id}/#{demo_version}/#{journal_id}-#{journal_version}"

    blob_id = Rails.cache.fetch(cache_key, expires_in: 1.week, race_condition_ttl: 10.minutes) do
      find_display_banner_blob_id
    end

    blob_id ? ActiveStorage::Blob.find_by(id: blob_id) : nil
  end

  def find_display_banner_blob_id
    return demo_picture.blob.id if demo_picture.attached?

    # Fall back to latest journal entry image if no demo_picture
    return unless latest_journal_entry&.content.present?

    image_match = latest_journal_entry.content.match(/!\[[^\]]*\]\(([^)]+)\)/)
    return unless image_match

    image_url = image_match[1]

    # Match standard ActiveStorage URLs
    if (match = image_url.match(%r{/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/]+)/}))
      return ActiveStorage::Blob.find_signed(match[1])&.id
    end

    # Match Marksmith/user-attachments URLs (Base64-encoded JSON with blob_id)
    if (match = image_url.match(%r{/user-attachments/blobs/(?:redirect/|proxy/)?([^/]+)/}))
      token = match[1].split("--").first
      decoded = JSON.parse(Base64.decode64(token))
      decoded.dig("_rails", "data") || decoded["data"]
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError, ArgumentError
    nil
  end

  scope :active, -> { where(is_deleted: false) }
  scope :listed, -> { where(unlisted: false) }
  scope :not_led, -> { where("ysws IS NULL OR ysws != ?", "led") }
  scope :with_valid_design_review, -> { joins(:valid_design_reviews).distinct }
  scope :without_valid_design_review, -> { left_outer_joins(:valid_design_reviews).where(valid_design_reviews: { id: nil }) }
  scope :with_valid_build_review, -> { joins(:valid_build_reviews).distinct }
  scope :without_valid_build_review, -> { left_outer_joins(:valid_build_reviews).where(valid_build_reviews: { id: nil }) }

  # Order projects by most recent journal entry; fall back to project creation
  scope :order_by_recent_journal, -> {
    left_joins(:journal_entries)
      .select("projects.*, COALESCE(MAX(journal_entries.created_at), projects.created_at) AS last_activity_at")
      .group("projects.id")
      .order(Arel.sql("last_activity_at DESC"))
  }

  before_validation :normalize_repo_link
  before_validation :set_funding_needed_cents_to_zero_if_no_funding
  before_validation :set_hackpad_tier
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
    refs = []
    refs << { type: :creation, date: created_at }
    refs.concat(timeline_journal_refs_cached)
    refs.concat(timeline_kudo_refs_cached)
    refs.concat(timeline_ship_refs_cached)
    refs.concat(timeline_review_refs_cached)
    refs.concat(timeline_package_sent_refs_cached)
    refs.concat(timeline_guide_next_steps_ref)

    timeline = hydrate_timeline_refs(refs)
    sorted = timeline.sort_by { |e| e[:date] }
    result = reverse ? sorted.reverse : sorted
    mark_most_recent_ship(result)
  end

  def timeline_journal_refs_cached
    cache_key = [ "project_timeline", id, "journals", journal_entries.maximum(:updated_at)&.to_f, journal_entries.count ]
    Rails.cache.fetch(cache_key) do
      journal_entries.order(created_at: :asc).pluck(:id, :created_at).map do |entry_id, created_at|
        { type: :journal, id: entry_id, date: created_at }
      end
    end
  end

  def timeline_kudo_refs_cached
    cache_key = [ "project_timeline", id, "kudos", kudos.maximum(:updated_at)&.to_f, kudos.count ]
    Rails.cache.fetch(cache_key) do
      kudos.order(created_at: :asc).pluck(:id, :created_at, :user_id).map do |kudo_id, created_at, user_id|
        { type: :kudo, id: kudo_id, date: created_at, user_id: user_id }
      end
    end
  end

  def timeline_ship_refs_cached
    cache_key = [ "project_timeline", id, "ships", versions.maximum(:id), versions.count ]
    Rails.cache.fetch(cache_key) do
      design_events = attribute_updated_event(object: self, attribute: :review_status, after: "design_pending", all: true)
      build_events = attribute_updated_event(object: self, attribute: :review_status, after: "build_pending", all: true)

      (design_events + build_events).map do |event|
        { type: :ship, date: event[:timestamp], user_id: event[:whodunnit] }
      end
    end
  end

  def timeline_review_refs_cached
    design_key = [ "project_timeline", id, "design_reviews", design_reviews.maximum(:updated_at)&.to_f, design_reviews.count ]
    build_key = [ "project_timeline", id, "build_reviews", build_reviews.maximum(:updated_at)&.to_f, build_reviews.count ]

    design_refs = Rails.cache.fetch(design_key) { build_design_review_refs }
    build_refs = Rails.cache.fetch(build_key) { build_build_review_refs }

    design_refs + build_refs
  end

  def timeline_package_sent_refs_cached
    package_type = case ysws
    when "hackpad" then :hackpad_kit
    when "led" then :blinky_kit
    end
    return [] unless package_type

    cache_key = [ "project_timeline", id, "package_sent", user_id, user.packages.maximum(:updated_at)&.to_f, user.packages.count ]
    Rails.cache.fetch(cache_key) do
      package = user.packages.find_by(package_type: package_type, sent_at: ..Time.current)
      return [] unless package&.sent_at

      [ { type: :package_sent, id: package.id, date: package.sent_at } ]
    end
  end

  def timeline_guide_next_steps_ref
    return [] unless ysws.in?(%w[hackpad led])
    return [] unless design_approved?
    return [] if timeline_package_sent_refs_cached.any?

    package_type = ysws == "hackpad" ? :hackpad_kit : :blinky_kit
    kit_sent = user.packages.exists?(package_type: package_type)
    iron_sent = true # TODO: check if soldering iron has been sent
    grant_sent = true # TODO: check if grant has been sent

    return [] if kit_sent && iron_sent && grant_sent

    [ { type: :guide_next_steps, date: 1.second.from_now, kit_sent: kit_sent, iron_sent: iron_sent, grant_sent: grant_sent } ]
  end

  def design_review_eta
    return nil unless design_pending?

    DesignReview.wait_time_estimator.remaining_for_project(project: self)
  end

  def build_review_eta
    return nil unless build_pending?

    BuildReview.wait_time_estimator.remaining_for_project(project: self)
  end

  def estimated_review_days
    eta = design_pending? ? design_review_eta : (build_pending? ? build_review_eta : nil)
    eta&.dig(:eta_days)
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

    # contents =
    # <<~EOS
    # <!--
    #   ===================    !!READ THIS NOTICE!!   ====================
    #   DO NOT edit this file manually. Your changes WILL BE OVERWRITTEN!
    #   This journal is auto generated and updated by Hack Club Blueprint.
    #   To edit this file, please edit your journal entries on Blueprint.
    #   ==================================================================
    # -->

    # EOS
    contents =
    <<~EOS
    <!--
      This journal is auto generated by Hack Club Blueprint.
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

  def self.guide_options
    [
      [ "I am not following a guide", "none" ],
      [ "Hackpad (Journal not required)", "hackpad" ],
      [ "Squeak (Journal not required)", "squeak" ],
      [ "Custom Devboard", "devboard" ],
      [ "Midi Keyboard", "midi" ],
      [ "Split Keyboard", "splitkb" ],
      [ "Blinky LED Chaser Board (Journal not required)", "led" ],
      [ "Other", "other" ]
    ]
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
      user.update(is_pro: true) unless user.is_pro?
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

  def is_currently_build?
    !needs_funding? || design_approved? || build_pending? || build_approved? || build_needs_revision? || build_rejected?
  end

  def submit_button_text
    if design_needs_revision?
      "Submit Design Re-review"
    elsif build_needs_revision?
      "Submit Build Re-review"
    elsif design_approved? || build_approved? || !needs_funding?
      "Submit Build Review"
    else
      "Submit Design Review"
    end
  end

  def followed_by?(user)
    user.followed_projects.include?(self)
  end

  def follower_count
    preloaded_follower_count || followers.count
  end

  def view_count
    preloaded_view_count || views_count
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
    return if Rails.env.development? || Rails.env.test?
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
      msg += "Your Blueprint project *#{title}* is now in the queue for design review. A reviewer will get to it soon!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    elsif build_pending?
      msg += "Your Blueprint project *#{title}* is now in the queue for build review. A reviewer will get to it soon!\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
    elsif design_needs_revision?
      review = design_reviews.where(result: "returned", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved. Here's some feedback from your reviewer, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Recommended tier:* #{review.tier_override}\n\n" if review.tier_override.present?
        msg += "*Recommended funding:* $#{'%.2f' % (review.grant_override_cents / 100.0)}\n\n" if review.grant_override_cents.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* needs some changes before it can be approved.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif design_rejected?
      review = design_reviews.where(result: "rejected", invalidated: false).last
      if review && review.feedback.present? && review.reviewer&.slack_id.present?
        msg += "Your Blueprint project *#{title}* has been rejected. You won't be able to submit again. Here's some feedback from your reviewer, <@#{review.reviewer.slack_id}>:\n\n#{review.feedback}\n\n"
        msg += "*Recommended tier:* #{review.tier_override}\n\n" if review.tier_override.present?
        msg += "*Grant to expect:* $#{'%.2f' % (review.grant_override_cents / 100.0)}\n\n" if review.grant_override_cents.present?
        msg += "<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      else
        msg += "Your Blueprint project *#{title}* has been rejected. You won't be able to submit again.\n\n<https://#{ENV.fetch("APPLICATION_HOST")}/projects/#{id}|View your project>\n\n"
      end
    elsif design_approved?
      msg += "Your Blueprint project *#{title}* has passed the design review! You should receive an email from HCB about your grant in a few business days.\n\n"

      if ysws != "hackpad" && ysws != "led" && ysws != "squeak"
        msg += "*Grant approved:* $#{'%.2f' % (approved_funding_cents / 100.0)}\n\n" if approved_funding_cents.present?
        msg += "*Tier approved:* #{approved_tier}\n\n" if approved_tier.present?
      end

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

    # Get approved reviews
    approved_design_reviews = design_reviews.where(result: "approved", invalidated: false, admin_review: true).order(created_at: :asc)
    approved_build_reviews = build_reviews.where(result: "approved", invalidated: false, admin_review: true).order(created_at: :asc)

    # Check if there's an hours override in any approved review
    has_override = approved_design_reviews.any? { |r| r.hours_override.present? } ||
                   approved_build_reviews.any? { |r| r.hours_override.present? }

    # Check if this is an LED project
    if ysws == "led"
      if !has_override
        hours_for_airtable = 5
      else
        total_effective_hours = 0
        approved_design_reviews.each { |r| total_effective_hours += r.effective_hours }
        approved_build_reviews.each { |r| total_effective_hours += r.effective_hours }
        hours_for_airtable = total_effective_hours
      end
      reasoning = "This project followed the 555 LED blinker guide. This was a guide that we have used at workshops before and which took students new to hardware a minimum of 5 hours to complete. This project at least meets the standards of a project submitted at this event. - Clay"
    elsif ysws == "hackpad"
      if !has_override
        hours_for_airtable = 15
      else
        total_effective_hours = 0
        approved_design_reviews.each { |r| total_effective_hours += r.effective_hours }
        approved_build_reviews.each { |r| total_effective_hours += r.effective_hours }
        hours_for_airtable = total_effective_hours
      end
      reasoning = "Previous Hack Pad projects have been surveyed and the average and median time spent has already been calculated. I (Clay Nicholson) reviewed and approved the submission and placed the order. The median submission based on this data spent 15 hours, while the mean was 20.
       This hackpad was more or less within that range of hours - nothing sticks out, so I am automatically approving these hours without reviewing the design."
    elsif ysws == "squeak"
      if !has_override
        hours_for_airtable = 5
      else
        total_effective_hours = 0
        approved_design_reviews.each { |r| total_effective_hours += r.effective_hours }
        approved_build_reviews.each { |r| total_effective_hours += r.effective_hours }
        hours_for_airtable = total_effective_hours
      end
      reasoning = "This project followed the Squeak guide. This project at least meets the standards of a project submitted at this event."
    else
      # Calculate total hours from ALL journal entries
      total_hours_logged = journal_entries.sum(:duration_seconds) / 3600.0

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
      "Screenshot" => (display_banner ? [
        {
          "url" => Rails.application.routes.url_helpers.rails_blob_url(display_banner, host: ENV.fetch("APPLICATION_HOST")),
          "filename" => display_banner.filename.to_s
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
      "BP Project ID" => id,
      "Review Type" => build_approved? ? "Build" : (design_approved? ? "Design" : nil),
      "Tickets Awarded" => valid_build_reviews.where(admin_review: true).sum { |review| review.tickets_awarded },
      "Phone Number" => idv_data.dig(:identity, :phone_number)
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

  def last_review_entry_at
    last_build_entry_at = build_reviews
      .where(result: :approved, invalidated: false, admin_review: true)
      .joins(:journal_entries)
      .maximum("journal_entries.created_at")

    last_design_entry_at = design_reviews
      .where(result: :approved, invalidated: false, admin_review: true)
      .joins(:journal_entries)
      .maximum("journal_entries.created_at")

    [ last_build_entry_at, last_design_entry_at ].compact.max
  end

  def unreviewed_journal_entries
    if last_review_entry_at
      journal_entries.where("created_at > ?", last_review_entry_at)
    else
      journal_entries
    end
  end

  def journal_entries_since_last_review
    unreviewed_journal_entries
  end

  def hours_since_last_review
    unreviewed_journal_entries.sum(:duration_seconds) / 3600.0
  end

  def entries_since_last_review_count
    unreviewed_journal_entries.count
  end

  def fix_review_status
    logs = []
    log = ->(msg) { logs << msg; Rails.logger.info "[fix_review_status] #{msg}" }

    log.call("Starting for project ##{id} (#{title})")
    log.call("Current review_status: #{review_status}")

    if review_status == "design_pending"
      latest_design_review = design_reviews.order(created_at: :desc).first

      if latest_design_review.nil?
        log.call("No design reviews found, skipping")
        return logs.join("\n")
      end

      log.call("Most recent design review ##{latest_design_review.id}: admin_review=#{latest_design_review.admin_review}, invalidated=#{latest_design_review.invalidated}, result=#{latest_design_review.result}")

      if latest_design_review.admin_review? && !latest_design_review.invalidated? && latest_design_review.approved?
        log.call("Design review meets all conditions, updating status to design_approved")
        update!(review_status: :design_approved)
        log.call("Successfully updated to design_approved")
      else
        log.call("Design review does not meet conditions, skipping")
      end

    elsif review_status == "build_pending"
      latest_build_review = build_reviews.order(created_at: :desc).first

      if latest_build_review.nil?
        log.call("No build reviews found, skipping")
        return logs.join("\n")
      end

      log.call("Most recent build review ##{latest_build_review.id}: admin_review=#{latest_build_review.admin_review}, invalidated=#{latest_build_review.invalidated}, result=#{latest_build_review.result}")

      if latest_build_review.admin_review? && !latest_build_review.invalidated? && latest_build_review.approved?
        log.call("Build review meets all conditions, updating status to build_approved")
        update!(review_status: :build_approved)
        log.call("Successfully updated to build_approved")
      else
        log.call("Build review does not meet conditions, skipping")
      end

    else
      log.call("Review status is neither design_pending nor build_pending, skipping")
    end

    logs.join("\n")
  end

  def normalize_repo_link
    normalized = Project.normalize_repo_link(repo_link, user&.github_username)
    self.repo_link = normalized if normalized.present?
  end

  def set_funding_needed_cents_to_zero_if_no_funding
    self.funding_needed_cents = 0 unless needs_funding?
  end

  def set_hackpad_tier
    self.tier = 4 if ysws == "hackpad" && tier.blank?
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

    return if Rails.env.development? || Rails.env.test?

    upload_to_airtable!
  end

  def approve_build!
    # Upload build review data to Airtable
    upload_to_airtable!
  end

  def notify_slack_on_submission!
    SlackProjectSubmissionJob.perform_later(id)
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

  private

  def approx_hour_one_decimal
    return if approx_hour.nil?
    errors.add(:approx_hour, "must have at most 1 decimal place") if approx_hour.round(1) != approx_hour
  end

  def build_design_review_refs
    refs = []
    all_reviews = design_reviews.where(result: %w[returned rejected])
                                .or(design_reviews.where(result: "approved", admin_review: true))
                                .order(created_at: :asc)
    previous_result = nil
    approve_group = nil

    all_reviews.each do |review|
      case review.result
      when "returned"
        refs << { type: :return_design, date: review.created_at, user_id: review.reviewer_id,
                  feedback: review.feedback, tier_override: review.tier_override, grant_override_cents: review.grant_override_cents }
      when "rejected"
        refs << { type: :reject_design, date: review.created_at, user_id: review.reviewer_id,
                  feedback: review.feedback, tier_override: review.tier_override, grant_override_cents: review.grant_override_cents }
      when "approved"
        if previous_result != "approved"
          approve_group = { type: :approve_design, date: review.created_at, reviews: [] }
          refs << approve_group
        end
        approve_group[:reviews] << { date: review.created_at, user_id: review.reviewer_id,
                                     feedback: review.feedback, tier_override: review.tier_override,
                                     grant_override_cents: review.grant_override_cents, admin_review: review.admin_review }
      end
      previous_result = review.result
    end
    refs
  end

  def build_build_review_refs
    refs = []
    all_reviews = build_reviews.where(result: %w[returned rejected])
                               .or(build_reviews.where(result: "approved", admin_review: true))
                               .order(created_at: :asc)
    previous_result = nil
    approve_group = nil

    all_reviews.each do |review|
      case review.result
      when "returned"
        refs << { type: :return_build, date: review.created_at, user_id: review.reviewer_id,
                  feedback: review.feedback, tier_override: review.tier_override }
      when "rejected"
        refs << { type: :reject_build, date: review.created_at, user_id: review.reviewer_id,
                  feedback: review.feedback, tier_override: review.tier_override }
      when "approved"
        if previous_result != "approved"
          approve_group = { type: :approve_build, date: review.created_at, reviews: [], tickets_awarded: review.tickets_awarded }
          refs << approve_group
        end
        approve_group[:reviews] << { date: review.created_at, user_id: review.reviewer_id,
                                     feedback: review.feedback, tier_override: review.tier_override, admin_review: review.admin_review }
        approve_group[:tickets_awarded] ||= review.tickets_awarded
      end
      previous_result = review.result
    end
    refs
  end

  def hydrate_timeline_refs(refs)
    journal_ids = refs.select { |r| r[:type] == :journal }.pluck(:id)
    kudo_ids = refs.select { |r| r[:type] == :kudo }.pluck(:id)
    package_ids = refs.select { |r| r[:type] == :package_sent }.pluck(:id)
    user_ids = refs.flat_map { |r| [ r[:user_id], r.dig(:reviews)&.pluck(:user_id) ] }
                   .flatten.compact.uniq
                   .select { |uid| uid.to_s.match?(/\A\d+\z/) }

    journals_by_id = JournalEntry.where(id: journal_ids).index_by(&:id)
    kudos_by_id = Kudo.where(id: kudo_ids).includes(:user).index_by(&:id)
    packages_by_id = Package.where(id: package_ids).index_by(&:id)
    users_by_id = User.where(id: user_ids).index_by { |u| u.id.to_s }

    refs.filter_map do |ref|
      case ref[:type]
      when :journal
        entry = journals_by_id[ref[:id]]
        next nil unless entry
        ref.merge(entry: entry)
      when :kudo
        kudo = kudos_by_id[ref[:id]]
        next nil unless kudo
        ref.merge(kudo: kudo)
      when :package_sent
        package = packages_by_id[ref[:id]]
        next nil unless package
        ref.merge(package: package)
      when :ship, :return_design, :reject_design, :return_build, :reject_build
        ref.merge(user: users_by_id[ref[:user_id].to_s])
      when :approve_design, :approve_build
        reviews_with_users = ref[:reviews].map { |r| r.merge(user: users_by_id[r[:user_id].to_s]) }
        ref.merge(reviews: reviews_with_users)
      else
        ref
      end
    end
  end

  def mark_most_recent_ship(timeline)
    most_recent_ship = timeline.find { |e| e[:type] == :ship }
    return timeline unless most_recent_ship

    most_recent_ship[:is_most_recent_ship] = true
    timeline
  end
end
