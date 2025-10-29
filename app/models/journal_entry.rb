# == Schema Information
#
# Table name: journal_entries
#
#  id               :bigint           not null, primary key
#  content          :text
#  duration_seconds :integer          default(0), not null
#  review_type      :string
#  summary          :string
#  views            :bigint           default([]), not null, is an Array
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  project_id       :bigint           not null
#  review_id        :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_journal_entries_on_project_id                 (project_id)
#  index_journal_entries_on_review                     (review_type,review_id)
#  index_journal_entries_on_review_type_and_review_id  (review_type,review_id)
#  index_journal_entries_on_user_id                    (user_id)
#  index_journal_entries_unreviewed_by_project         (project_id,created_at) WHERE (review_id IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class JournalEntry < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :review, polymorphic: true, optional: true

  has_one_attached :attachment

  validates :attachment, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif", "application/pdf" ],
                         size: { less_than: 10.megabytes }

  MIN_CHARS = 150

  validate :content_min_chars_excluding_images
  validate :content_must_include_image
  validates :summary, presence: true, length: { maximum: 60 }

  after_commit :sync_project_github_journal, on: %i[create update destroy]
  after_commit :sync_project_to_gorse, on: %i[create update destroy]
  after_commit :sync_entry_to_gorse, on: %i[create update]
  after_commit :delete_entry_from_gorse, on: :destroy
  after_commit :notify_followers, on: :create

  def rendered_html
    return "" if content.blank?

    Rails.cache.fetch("journal_entry_html/#{cache_key_with_version}", expires_in: 1.week) do
      base_url = Rails.application.routes.default_url_options[:host] || "localhost:3000"
      Marksmith::Renderer.new(body: content, base_url: "http://#{base_url}").render
    end
  end

  private

  def content_min_chars_excluding_images
    body = content.to_s
    without_images = body.gsub(/!\[[^\]]*\]\([^)]+\)/, "")
    normalized = without_images.lines.map { |l| l.strip }.join
    if normalized.length < MIN_CHARS
      errors.add(:content, "is too short; add more details (min #{MIN_CHARS} characters excluding images)")
    end
  end

  def content_must_include_image
    body = content.to_s
    images = body.scan(/!\[[^\]]*\]\([^)]+\)/)
    if images.size < 1
      errors.add(:content, "must include at least one image")
    end
  end

  def sync_project_github_journal
    project&.sync_github_journal!
  rescue => e
    Rails.logger.error("Failed to enqueue GitHub journal sync for project #{project_id}: #{e.message}")
    Sentry.capture_exception(e)
  end

  def sync_project_to_gorse
    project&.sync_to_gorse
  end

  def sync_entry_to_gorse
    GorseSyncJournalEntryJob.perform_later(id)
  end

  def delete_entry_from_gorse
    GorseService.delete_item(self)
  rescue => e
    Rails.logger.error("Failed to delete journal entry #{id} from Gorse: #{e.message}")
    Sentry.capture_exception(e)
  end

  def notify_followers
    follower_slack_ids = project.followers.where.not(slack_id: nil).pluck(:slack_id)
    return if follower_slack_ids.empty?

    host = ENV.fetch("APPLICATION_HOST", "blueprint.hackclub.com")
    url_helpers = Rails.application.routes.url_helpers

    author_name = if user.slack_id.present?
      "<@#{user.slack_id}>"
    else
      user_url = url_helpers.user_url(user, host: host)
      display_name = user.display_name || user.username || "Someone"
      "<#{user_url}|#{display_name}>"
    end

    project_url = url_helpers.project_url(project, host: host)
    project_link = "<#{project_url}|#{project.title}>"

    entry_url = url_helpers.project_journal_entry_url(project, self, host: host)
    message = "#{author_name} posted a new journal entry on #{project_link}: <#{entry_url}|#{summary}>"

    follower_slack_ids.each do |slack_id|
      SlackDmJob.perform_later(slack_id, message)
    end
  rescue => e
    Rails.logger.error("Failed to send follower notifications for journal entry #{id}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
