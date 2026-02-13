# == Schema Information
#
# Table name: kudos
#
#  id         :bigint           not null, primary key
#  content    :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_kudos_on_project_id  (project_id)
#  index_kudos_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Kudo < ApplicationRecord
  belongs_to :user
  belongs_to :project, counter_cache: true

  validates :content, presence: true
  validate :user_cannot_give_kudos_to_own_project

  after_commit :notify_project_owner, on: :create

  private

  def user_cannot_give_kudos_to_own_project
    if user_id == project&.user_id
      errors.add(:user, "cannot give kudos to your own project")
    end
  end

  def notify_project_owner
    return unless project.user.slack_id.present?

    host = ENV.fetch("APPLICATION_HOST", "hackworks.hackclub.dev")
    url_helpers = Rails.application.routes.url_helpers

    kudo_giver = if user.slack_id.present?
      "<@#{user.slack_id}>"
    else
      user_url = url_helpers.user_url(user, host: host)
      display_name = user.display_name || user.username || "Someone"
      "<#{user_url}|#{display_name}>"
    end

    project_url = url_helpers.project_url(project, host: host)
    project_link = "<#{project_url}|#{project.title}>"

    message = "#{kudo_giver} gave you kudos on #{project_link}, here's what they wrote:\n> #{content}"

    SlackDmJob.perform_later(project.user.slack_id, message)
  rescue => e
    Rails.logger.error("Failed to send kudos notification for kudo #{id}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
