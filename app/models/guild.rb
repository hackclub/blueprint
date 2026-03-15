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
class Guild < ApplicationRecord
  validates :name, presence: true
  validates :city, presence: true, uniqueness: true

  has_many :guild_signups, dependent: :destroy
  has_many :users, through: :guild_signups

  enum :status, { pending: 0, active: 1, full: 2 }, default: :pending, validate: true
  geocoded_by :city
  after_validation :geocode, if: ->(obj) { obj.city.present? && obj.city_changed? }

  def update_slack_topic
    puts ">>> update_slack_topic called for guild #{id} (city: #{city})"
    puts ">>> slack_channel_id: #{slack_channel_id.inspect}"
    return unless slack_channel_id.present?

    organizer_slack_ids = guild_signups
                          .where(role: :organizer)
                          .joins(:user)
                          .where.not(users: { slack_id: nil })
                          .pluck("users.slack_id")
                          .uniq
    puts ">>> organizer Slack IDs: #{organizer_slack_ids.inspect}"

    mentions = organizer_slack_ids.map { |id| "<@#{id}>" }.join(", ")
    topic = "Build Guild for #{city}! Organizers: #{mentions}"
    puts ">>> topic: #{topic}"

    token = ENV["GUILDS_BOT_TOKEN"]
    puts ">>> token present? #{token.present?}"
    slack_client = Slack::Web::Client.new(token: token)

    puts ">>> calling Slack API..."
    response = slack_client.conversations_setTopic(channel: slack_channel_id, topic: topic)
    puts ">>> response class: #{response.class}"
    puts ">>> response: #{response.inspect}"
  rescue => e
    puts ">>> error: #{e.class} - #{e.message}"
  end
  def days_pending
    return 0 unless pending?
    (Time.current - created_at) / 1.day
  end
  def map_data
    @guilds = Guild.includes(:guild_signups).all
    render json: @guilds.map { |g|
      {
        id: g.id,
        name: g.name,
        city: g.city,
        lat: g.latitude,
        lng: g.longitude,
        signup_count: g.guild_signups.count
      }
    }
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

  after_commit :sync_to_airtable, on: [ :create, :update ]

    def airtable_record_id
    GuildAirtableSync.find_by(record_identifier: "Guild##{id}")&.airtable_id
  end

  def sync_to_airtablegeo
    GuildAirtableSync.sync_records!(self.class, [ self ])
  end
end
