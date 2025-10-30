# == Schema Information
#
# Table name: design_reviews
#
#  id                          :bigint           not null, primary key
#  admin_review                :boolean
#  feedback                    :text
#  frozen_duration_seconds     :integer
#  frozen_entry_count          :integer
#  frozen_funding_needed_cents :integer
#  frozen_tier                 :integer
#  grant_override_cents        :integer
#  hours_override              :float
#  invalidated                 :boolean          default(FALSE)
#  reason                      :string
#  result                      :integer
#  tier_override               :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  project_id                  :bigint           not null
#  reviewer_id                 :bigint           not null
#
# Indexes
#
#  index_design_reviews_on_project_id                  (project_id)
#  index_design_reviews_on_reviewer_id                 (reviewer_id)
#  index_design_reviews_on_reviewer_id_and_project_id  (reviewer_id,project_id) UNIQUE WHERE (invalidated = false)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class DesignReview < ApplicationRecord
  belongs_to :reviewer, class_name: "User"
  belongs_to :project

  enum :result, { approved: 0, returned: 1, rejected: 2 }

  validates :reviewer_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where(invalidated: false) },
    message: "has already reviewed this project"
  }
  validates :hours_override, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :result, presence: true

  has_many :journal_entries, as: :review, dependent: :nullify

  before_create :freeze_project_state
  after_save :finalize_on_approve, if: -> { saved_change_to_result? && approved? && !invalidated? }

  def effective_hours
    hours_override || (frozen_duration_seconds && approved? ? frozen_duration_seconds / 3600.0 : journal_entries.sum(:duration_seconds) / 3600.0)
  end

  def self.backfill_journal_associations!
    # Utility method to backfill journal entry associations for existing approved reviews
    DesignReview.where(result: "approved", invalidated: false, admin_review: true).find_each do |review|
      review.associate_journal_entries!
    end
  end

  def associate_journal_entries!(up_to: nil)
    # Associate all journal entries created after the last approval and at or before this review
    cutoff = up_to || created_at

    # Find the most recent valid approval (from either build or design review) at or before this review
    last_approval = project.build_reviews
                           .where(result: :approved, invalidated: false)
                           .where("created_at <= ?", cutoff)
                           .order(created_at: :desc, id: :desc)
                           .first

    last_design_approval = project.design_reviews
                                  .where(result: :approved, invalidated: false, admin_review: true)
                                  .where.not(id: id)
                                  .where("created_at <= ?", cutoff)
                                  .order(created_at: :desc, id: :desc)
                                  .first

    last_valid_approval_time = [ last_approval&.created_at, last_design_approval&.created_at ].compact.max

    # Associate entries created after the last approval and at or before the cutoff
    entries = project.journal_entries.where("created_at <= ?", cutoff)
    entries = entries.where("created_at > ?", last_valid_approval_time) if last_valid_approval_time

    entries.update_all(review_id: id, review_type: "DesignReview")
  end

  private

  def freeze_project_state
    self.frozen_funding_needed_cents = project.funding_needed_cents
    self.frozen_duration_seconds = project.journal_entries.sum(:duration_seconds)
    self.frozen_tier = project.tier
    self.frozen_entry_count = project.journal_entries.count
  end

  def finalize_on_approve
    return unless admin_review? # Only admin approvals finalize

    transaction do
      # Associate all currently unreviewed journal entries
      associate_journal_entries!(up_to: Time.current)

      # Update frozen fields with actual associated entries
      update_columns(
        frozen_duration_seconds: journal_entries.sum(:duration_seconds),
        frozen_entry_count: journal_entries.count,
        frozen_funding_needed_cents: project.funding_needed_cents,
        frozen_tier: project.tier,
        updated_at: Time.current
      )
    end
  end
end
