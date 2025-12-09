# == Schema Information
#
# Table name: build_reviews
#
#  id                      :bigint           not null, primary key
#  admin_review            :boolean
#  feedback                :text
#  frozen_duration_seconds :integer
#  frozen_entry_count      :integer
#  frozen_reviewer_note    :text
#  frozen_tier             :integer
#  hours_override          :float
#  invalidated             :boolean          default(FALSE)
#  reason                  :string
#  result                  :integer
#  ticket_multiplier       :float
#  ticket_offset           :integer
#  tier_override           :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  project_id              :bigint           not null
#  reviewer_id             :bigint           not null
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
  has_many :journal_entries, as: :review, dependent: :nullify

  enum :result, { approved: 0, returned: 1, rejected: 2 }

  validates :reviewer_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where(invalidated: false) },
    message: "has already reviewed this project"
  }
  validates :result, presence: true
  validates :ticket_multiplier, numericality: true, allow_nil: true
  validates :ticket_offset, numericality: { only_integer: true }, allow_nil: true
  validates :tier_override, inclusion: { in: 1..5 }, allow_nil: true
  validates :hours_override, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :set_default_tier_override, on: :create
  before_create :freeze_project_state
  after_save :finalize_on_approve, if: -> { saved_change_to_result? && approved? && !invalidated? }

  def self.default_multiplier_for_tier(tier)
    case tier
    when nil, 5 then 0.8
    when 4 then 1.0
    when 3 then 1.1
    when 2 then 1.25
    when 1 then 1.5
    else 0.8
    end
  end

  def self.tier_options_with_multipliers
    tier_multipliers = { 1 => "×1.5", 2 => "×1.25", 3 => "×1.1", 4 => "×1.0", 5 => "×0.8" }
    Project.tiers.map { |key, value| [ "Tier #{key} (#{tier_multipliers[key.to_i]})", value ] }
  end

  def effective_tier
    tier_override || project.tier
  end

  def effective_hours
    hours_override || (frozen_duration_seconds && approved? ? frozen_duration_seconds / 3600.0 : journal_entries.sum(:duration_seconds) / 3600.0)
  end

  def tickets_awarded
    ((effective_hours * 10 * (ticket_multiplier || 0.8)) + (ticket_offset || 0)).round
  end

  def associate_journal_entries!(up_to: nil)
    cutoff = up_to || created_at

    # Find IDs of all prior approved reviews
    prev_approved_build_ids = project.build_reviews
                                     .where(result: :approved, invalidated: false)
                                     .where.not(id: id)
                                     .pluck(:id)

    prev_admin_design_ids = project.design_reviews
                                   .where(result: :approved, invalidated: false, admin_review: true)
                                   .pluck(:id)

    # Use the timestamp of the last associated journal entry from any prior approved review as cutoff
    # This prevents double-counting and ensures correct partitioning across review rounds
    last_build_entry_at = prev_approved_build_ids.any? ?
                            JournalEntry.where(review_type: "BuildReview", review_id: prev_approved_build_ids).maximum(:created_at) : nil
    last_design_entry_at = prev_admin_design_ids.any? ?
                             JournalEntry.where(review_type: "DesignReview", review_id: prev_admin_design_ids).maximum(:created_at) : nil

    last_valid_approval_time = [ last_build_entry_at, last_design_entry_at ].compact.max

    # Associate entries created after the last approval and at or before the cutoff
    # Only associate unreviewed entries to never reassign already-associated ones
    entries = project.journal_entries.where("created_at <= ?", cutoff).where(review_id: nil)
    entries = entries.where("created_at > ?", last_valid_approval_time) if last_valid_approval_time

    entries.update_all(review_id: id, review_type: "BuildReview")
  end

  def self.backfill_journal_associations!
    # Deprecated: Use the reviews:backfill rake task instead, which correctly associates
    # journal entries up to the review's created_at, not Time.current
    BuildReview.where(result: :approved, invalidated: false).find_each do |review|
      review.associate_journal_entries!(up_to: review.created_at)
    end
  end

  private

  def set_default_tier_override
    self.tier_override ||= project.tier
  end

  def freeze_project_state
    self.frozen_reviewer_note = project.reviewer_note
  end

  def finalize_on_approve
    transaction do
      now = Time.current
      self.tier_override ||= project.tier
      self.ticket_multiplier ||= BuildReview.default_multiplier_for_tier(effective_tier)
      self.ticket_offset ||= 0

      associate_journal_entries!(up_to: now)

      frozen_duration = JournalEntry.where(review: self).sum(:duration_seconds)
      frozen_count = JournalEntry.where(review: self).count
      frozen_t = effective_tier

      update_columns(
        tier_override: tier_override,
        ticket_multiplier: ticket_multiplier,
        ticket_offset: ticket_offset,
        frozen_duration_seconds: frozen_duration,
        frozen_entry_count: frozen_count,
        frozen_tier: frozen_t,
        updated_at: now
      )
    end
  end
end
