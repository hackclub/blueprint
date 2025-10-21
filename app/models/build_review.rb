# == Schema Information
#
# Table name: build_reviews
#
#  id                          :bigint           not null, primary key
#  admin_review                :boolean
#  feedback                    :text
#  frozen_duration_seconds     :integer
#  frozen_entry_count          :integer
#  frozen_funding_needed_cents :integer
#  frozen_tier                 :integer
#  hours_override              :float
#  invalidated                 :boolean          default(FALSE)
#  reason                      :string
#  result                      :integer
#  ticket_override             :integer
#  tier_override               :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  project_id                  :bigint           not null
#  reviewer_id                 :bigint           not null
#
# Indexes
#
#  index_build_reviews_on_project_id                  (project_id)
#  index_build_reviews_on_reviewer_id                 (reviewer_id)
#  index_build_reviews_on_reviewer_id_and_project_id  (reviewer_id,project_id) UNIQUE WHERE (invalidated = false)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class BuildReview < ApplicationRecord
  belongs_to :reviewer, class_name: "User"
  belongs_to :project

  enum :result, { approved: 0, returned: 1, rejected: 2 }

  validates :reviewer_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where(invalidated: false) },
    message: "has already reviewed this project"
  }

  before_create :freeze_project_state

  private

  def freeze_project_state
    self.frozen_duration_seconds = project.journal_entries.sum(:duration_seconds)
    self.frozen_tier = project.tier
    self.frozen_entry_count = project.journal_entries.count
  end
end
