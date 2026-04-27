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

  def invite_slug
    slug = city.parameterize
    if Guild.where.not(status: :closed).where.not(id: id).any? { |g| g.city.parameterize == slug }
      "#{slug}-#{country}"
    else
      slug
    end
  end

  def invite_url
    "https://blueprint.hackclub.com/guilds/invite/#{invite_slug}"
  end

  before_save :clear_needs_review_if_closed
  after_validation :geocode, if: ->(obj) { obj.city.present? && obj.city_changed? && obj.latitude.blank? }
  after_commit :sync_to_airtable, on: [ :create, :update ] # not :delete to preserve history, we close guilds rather than deleting them from airtable

  def update_slack_topic
    return unless slack_channel_id.present?

    organizer_slack_ids = guild_signups
                          .where(role: :organizer)
                          .joins(:user)
                          .where.not(users: { slack_id: nil })
                          .pluck("users.slack_id")
                          .uniq

    mentions = organizer_slack_ids.map { |id| "<@#{id}>" }.join(", ")
    topic = "Build Guild for #{city}! Organizers: #{mentions} | Invite: #{invite_url}"

    slack_client = Slack::Web::Client.new(token: ENV["GUILDS_BOT_TOKEN"])
    slack_client.conversations_setTopic(channel: slack_channel_id, topic: topic)
  rescue
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
      "created_at" => :created_at,
      "poc_name" => ->(guild) { guild.guild_signups.where(role: :organizer).order(:created_at).first&.name },
      "poc_email" => ->(guild) { guild.guild_signups.where(role: :organizer).order(:created_at).first&.email },
      "poc_birthday" => ->(guild) { guild.guild_signups.where(role: :organizer).order(:created_at).first&.user&.birthday&.iso8601 }
    }
  end

  def clear_needs_review_if_closed
    self.needs_review = false if status_changed? && closed?
  end

  def sync_to_airtable
    return if ENV["DISABLE_AIRTABLE_SYNC"].present?
    AirtableSync.sync_records!(self.class, [ self ])
  rescue
  end

  def airtable_record_id
    AirtableSync.find_by(record_identifier: "Guild##{id}")&.airtable_id
  end

  GUILD_WEBSITES = {
    "Delhi" => "https://buildguilddelhi.space/",
    "Dubai" => "https://build-guilds-dubai.vercel.app/",
    "Lucknow" => "https://www.lucknow-build-guild.xyz/",
    "Kochi" => "https://buildguildkochi.netlify.app/",
    "Oxford" => "https://katetriestocode.github.io/buildguildoxford/",
    "Siliguri" => "https://buildguildsiliguri.xyz/",
    "Ahmedabad" => "https://buildguild-ahmedabad.vercel.app/",
    "Toronto" => "http://buildguildtoronto.xyz/",
    "Berkeley" => "https://coding-koala222.github.io/berkeley-build-guild-website/",
    "Bhopal" => "https://www.makerani.tech/"
  }.freeze

  def website_url
    GUILD_WEBSITES[city]
  end

  MAX_ANNOUNCEMENTS = 20

  def description_data
    return { "announcements" => [] } if description.blank?
    parsed = JSON.parse(description)
    if parsed.is_a?(Hash)
      parsed["announcements"] ||= []
      parsed
    elsif parsed.is_a?(Array)
      { "announcements" => parsed }
    else
      { "announcements" => [] }
    end
  rescue JSON::ParserError
    { "announcements" => [ { "body" => description, "posted_at" => updated_at.iso8601, "author_name" => "Organizer" } ] }
  end

  def write_description_data!(data)
    data = data.dup
    data.delete("signups_closed_at") if data["signups_closed_at"].blank?
    data.delete("closed_by_admin") if data["signups_closed_at"].blank?
    if data["announcements"].blank? && data["signups_closed_at"].blank?
      update_column(:description, nil)
    else
      update_column(:description, data.to_json)
    end
  end

  def announcements
    description_data["announcements"] || []
  end

  def add_announcement!(body, author_name)
    data = description_data
    entries = data["announcements"] || []
    entries.unshift({ "body" => body, "posted_at" => Time.current.iso8601, "author_name" => author_name })
    data["announcements"] = entries.first(MAX_ANNOUNCEMENTS)
    write_description_data!(data)
  end

  def delete_announcement!(posted_at)
    data = description_data
    entries = data["announcements"] || []
    entries.reject! { |a| a["posted_at"] == posted_at }
    data["announcements"] = entries
    write_description_data!(data)
  end

  def signups_closed_at
    raw = description_data["signups_closed_at"]
    Time.parse(raw) if raw.present?
  rescue ArgumentError
    nil
  end

  def signups_closed?
    description_data["signups_closed_at"].present?
  end

  def signups_closed_by_admin?
    signups_closed? && description_data["closed_by_admin"] == true
  end

  def close_signups!(by_admin: false)
    data = description_data
    data["signups_closed_at"] = Time.current.iso8601
    data["closed_by_admin"] = true if by_admin
    write_description_data!(data)
  end

  def reopen_signups!
    data = description_data
    data.delete("signups_closed_at")
    data.delete("closed_by_admin")
    write_description_data!(data)
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
