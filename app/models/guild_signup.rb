# == Schema Information
#
# Table name: guild_signups
#
#  id                  :bigint           not null, primary key
#  attendee_activities :text
#  country             :string
#  email               :string
#  ideas               :text
#  name                :string
#  project_link        :string
#  role                :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  guild_id            :bigint           not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_guild_signups_on_guild_id              (guild_id)
#  index_guild_signups_on_user_id               (user_id)
#  index_guild_signups_on_user_id_and_guild_id  (user_id,guild_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (guild_id => guilds.id)
#  fk_rails_...  (user_id => users.id)
#
class GuildSignup < ApplicationRecord
  belongs_to :user
  belongs_to :guild

  attr_accessor :skip_slack_validation, :skip_admin_validations

  enum :role, { organizer: 0, attendee: 1 }

  after_commit :enqueue_processing_job, on: :create
  after_commit :send_confirmation_email, on: :create
  after_commit :sync_to_airtable, on: [ :create, :update ]
  after_commit :sync_guild_to_airtable, on: [ :create, :update ], if: :organizer?

  validates :name, :email, :role, :country, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :ideas, presence: true, if: -> { organizer? && !skip_admin_validations }
  validate :user_must_have_approved_project, if: -> { organizer? && !skip_admin_validations }
  validates :user_id, uniqueness: { scope: :guild_id, message: "You have already signed up for this guild" }
  validate :user_must_have_slack_id, unless: :skip_slack_validation
  validate :one_organizer_signup_only, if: :organizer?

  after_destroy :update_guild_topic, if: :organizer?
  after_destroy :sync_guild_to_airtable, if: :organizer?
  after_destroy :mark_guild_pending_if_no_organizer, if: :organizer?

  def one_organizer_signup_only
    existing = GuildSignup.where(user_id: user_id, role: :organizer)
    existing = existing.where.not(id: id) if persisted?
    if existing.exists?
      errors.add(:base, "You can only organize one guild. You're already organizing another guild.")
    end
  end

  def user_must_have_slack_id
    unless user&.slack_id.present?
      errors.add(:base, "You must be in the Hack Club Slack to join a guild. Log in with Slack or link your Slack account first.")
    end
  end

  def user_must_have_approved_project
    unless user&.has_approved_project?
      errors.add(:base, "You need an approved Blueprint project to organize a guild.")
    end
  end

  def self.airtable_sync_base_id
    ENV["AIRTABLE_GUILDS_BASE_ID"]
  end

  def self.airtable_sync_table_id
    ENV["AIRTABLE_SIGNUPS_TABLE_ID"]
  end

  def self.airtable_sync_field_mappings
    {
      "signup_id" => :id,
      "guild_id" => :guild_id,
      "user_id" => :user_id,
      "slack_id" => ->(r) { r.user&.slack_id },
      "name" => :name,
      "email" => :email,
      "role" => :role,
      "country" => :country,
      "ideas" => :ideas,
      "attendee_activities" => :attendee_activities,
      "created_at" => ->(r) { r.created_at&.iso8601 }
    }
  end

  private

  def enqueue_processing_job
    ProcessGuildSignupJob.perform_later(id)
  end

  def send_confirmation_email
    SendGuildEmailJob.perform_later(id)
  end

  def sync_to_airtable
    return if ENV["DISABLE_AIRTABLE_SYNC"].present?
    AirtableSync.sync_records!(self.class, [ self ])
  rescue => e
    Rails.logger.error "Failed to sync guild signup #{id} to Airtable: #{e.message}"
  end

  def update_guild_topic
    guild.update_slack_topic if guild.present?
  end

  def sync_guild_to_airtable
    return if ENV["DISABLE_AIRTABLE_SYNC"].present?
    guild.sync_to_airtable if guild.present?
  end

  def mark_guild_pending_if_no_organizer
    return unless organizer?
    return unless guild.present?
    return unless guild.active?
    return if guild.guild_signups.where(role: :organizer).exists?

    guild.update!(status: :pending)
  end
end
