# == Schema Information
#
# Table name: guilds
#
#  id               :bigint           not null, primary key
#  city             :string           not null
#  country          :string
#  description      :text
#  latitude         :float
#  longitude        :float
#  name             :string
#  needs_review     :boolean
#  status           :integer          default("pending")
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

  def invite_url
    "https://blueprint.hackclub.com/guilds/invite/#{city.parameterize}"
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
    return if ENV["DISABLE_AIRTABLE_SYNC"].present?
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
      organizers = g.guild_signups.select(&:organizer?).map(&:user).select { |u| u.slack_id.present? }
      organizer_text = organizers.any? ? ": #{organizers.map { |u| "<@#{u.slack_id}>" }.join(", ")}" : ""
      "• <##{g.slack_channel_id}>#{organizer_text}"
    end

    text = "*Build Guild Channels*\n\n"
    text += lines.any? ? lines.join("\n") : "No active guild channels yet."

    pins = slack_client.pins_list(channel: MAIN_CHANNEL_ID)
    bot_pin = pins["items"]&.find { |p| p.dig("message", "bot_id").present? && p.dig("message", "text")&.start_with?("*Build Guild Channels*") }

    if bot_pin
      ts = bot_pin.dig("message", "ts")
      slack_client.chat_update(channel: MAIN_CHANNEL_ID, ts: ts, text: text)
      { updated: true, total: guilds_with_channels.count }
    else
      response = slack_client.chat_postMessage(channel: MAIN_CHANNEL_ID, text: text)
      slack_client.pins_add(channel: MAIN_CHANNEL_ID, timestamp: response["ts"])
      { updated: false, total: guilds_with_channels.count }
    end
  end
end
