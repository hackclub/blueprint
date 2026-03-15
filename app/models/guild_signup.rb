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

  enum :role, { organizer: 0, attendee: 1 }

  after_commit :enqueue_processing_job, on: :create

  validates :name, :email, :role, :country, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :ideas, presence: true, if: :organizer?
  validate :user_must_have_approved_project, if: :organizer?
  validates :user_id, uniqueness: { scope: :guild_id, message: "You have already signed up for this guild" }

  after_destroy :update_guild_topic, if: :organizer?

  def user_must_have_approved_project
    unless user&.has_approved_project?
      errors.add(:base, "You need an approved Blueprint project to organize a guild.")
    end
  end

  private

  def enqueue_processing_job
    ProcessGuildSignupJob.perform_later(id)
  end

  def update_guild_topic
    puts ">>> update_guild_topic called for signup #{id}"
    if guild.present?
      puts ">>> guild present, calling update_slack_topic"
      guild.update_slack_topic
    else
      puts ">>> guild is nil"
    end
  end
end
