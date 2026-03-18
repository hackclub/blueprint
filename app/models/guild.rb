# == Schema Information
#
# Table name: guilds
#
#  id               :bigint           not null, primary key
#  city             :string
#  country          :string
#  description      :text
#  latitude         :float
#  longitude        :float
#  name             :string
#  needs_review     :boolean
#  status           :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  slack_channel_id :string
#
# Indexes
#
#  index_guilds_on_city_and_country  (city,country) UNIQUE
#
class Guild < ApplicationRecord
  validates :name, presence: true
  validates :city, presence: true, uniqueness: { scope: :country, case_sensitive: false }

  has_many :guild_signups, dependent: :destroy
  has_many :users, through: :guild_signups

  enum :status, { pending: 0, active: 1, closed: 2 }, default: :pending, validate: true
  scope :open, -> { where.not(status: :closed) }
  geocoded_by :full_location

  def full_location
    [ city, country ].compact.join(", ")
  end

  after_validation :geocode, if: ->(obj) { obj.city.present? && obj.city_changed? && obj.latitude.blank? }
  after_commit :sync_to_airtable, on: [ :create, :update ]

  def update_slack_topic
    return unless slack_channel_id.present?

    organizer_slack_ids = guild_signups
                          .where(role: :organizer)
                          .joins(:user)
                          .where.not(users: { slack_id: nil })
                          .pluck("users.slack_id")
                          .uniq

    mentions = organizer_slack_ids.map { |id| "<@#{id}>" }.join(", ")
    topic = "Build Guild for #{city}! Organizers: #{mentions}"

    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.conversations_setTopic(channel: slack_channel_id, topic: topic)
  rescue => e
    Rails.logger.error "Failed to update Slack topic for guild #{id}: #{e.message}"
  end
  def days_pending
    return 0 unless pending?
    (Time.current - created_at) / 1.day
  end
  def self.airtable_sync_base_id
    ENV["AIRTABLE_GUILDS_BASE_ID"]
  end

  def self.airtable_sync_table_id
    ENV["AIRTABLE_GUILDS_TABLE_ID"]
  end

  def self.airtable_sync_field_mappings
    {
      "guild_id" => :id,
      "name" => :name,
      "city" => :city,
      "country" => :country,
      "status" => :status,
      "slack_channel_id" => :slack_channel_id,
      "needs_review" => :needs_review,
      "created_at" => :created_at
    }
  end

  def sync_to_airtable
    AirtableSync.sync_records!(self.class, [ self ])
  rescue => e
    Rails.logger.error "Failed to sync guild #{id} to Airtable: #{e.message}"
  end

  def airtable_record_id
    AirtableSync.find_by(record_identifier: "Guild##{id}")&.airtable_id
  end

  MAIN_CHANNEL_ID = "C0ALTV3HBGB"

  def self.update_main_channel_description
    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    guilds_with_channels = Guild.where.not(slack_channel_id: nil).where.not(status: :closed).includes(guild_signups: :user).order(:city)

    lines = guilds_with_channels.map do |g|
      organizer_handles = g.guild_signups
                           .select(&:organizer?)
                           .map(&:user)
                           .select { |u| u.slack_id.present? }
                           .map { |u| "<@#{u.slack_id}>" }
      organizer_text = organizer_handles.any? ? " — #{organizer_handles.join(', ')}" : ""
      "- <##{g.slack_channel_id}|build-guild-#{g.city.parameterize}>#{organizer_text}"
    end

    markdown = "# Build Guild Channels\n\n"
    markdown += lines.any? ? lines.join("\n") : "No active guild channels yet."

    channel_info = slack_client.conversations_info(channel: MAIN_CHANNEL_ID)
    canvas_id = channel_info.dig("channel", "properties", "canvas", "file_id")

    if canvas_id
      # Rebuild all sections so organizer info stays current
      sections_response = slack_client.canvases_sections_lookup(
        canvas_id: canvas_id,
        criteria: { section_types: [ "any_header", "any_text" ] }.to_json
      )
      section_ids = sections_response["sections"]&.map { |s| s["id"] } || []

      changes = section_ids.map { |sid| { operation: "delete", section_id: sid } }
      changes << { operation: "insert_at_start", document_content: { type: "markdown", markdown: markdown } }

      slack_client.canvases_edit(canvas_id: canvas_id, changes: changes.to_json)

      { canvas_id: canvas_id, new_count: nil, total: guilds_with_channels.count }
    else
      slack_client.conversations_canvases_create(
        channel_id: MAIN_CHANNEL_ID,
        document_content: { type: "markdown", markdown: markdown }.to_json
      )

      { canvas_id: nil, new_count: guilds_with_channels.count, total: guilds_with_channels.count }
    end
  end
end
