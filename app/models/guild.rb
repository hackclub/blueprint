# == Schema Information
#
# Table name: guilds
#
#  id               :bigint           not null, primary key
#  city             :string
#  description      :text
#  name             :string
#  slack_channel_id :string
#  status           :integer          default("pending")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_guilds_on_city  (city) UNIQUE
#
class Guild < ApplicationRecord
  validates :name, presence: true
  validates :city, presence: true, uniqueness: true

  has_many :guild_signups, dependent: :destroy
  has_many :users, through: :guild_signups

  enum :status, { pending: 0, active: 1, full: 2 }, default: :pending, validate: true

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

    token = ENV["SLACK_BOT_TOKEN"]
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
end
