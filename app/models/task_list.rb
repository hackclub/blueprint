# == Schema Information
#
# Table name: task_lists
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_task_lists_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TaskList < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  def task_requirements
    {
      join_slack: {
        met: user.slack_user? && !user.is_mcg?,
        msg: "Join the Hack Club Slack"
    },
      create_project: {
        met: user.projects.any?,
        msg: "Start your first project"
      }
    }
  end

  def completed_tasks
    task_requirements.select { |_, req| req[:met] }
  end

  def pending_tasks
    task_requirements.reject { |_, req| req[:met] }
  end

  def task_completed?(task)
    task_requirements[task][:met]
  end

  def completed?
    pending_tasks.empty?
  end
end
