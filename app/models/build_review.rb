# == Schema Information
#
# Table name: build_reviews
#
#  id                      :bigint           not null, primary key
#  admin_review            :boolean
#  feedback                :text
#  frozen_duration_seconds :integer
#  frozen_entry_count      :integer
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
  after_update :finalize_on_approve, if: -> { saved_change_to_result? && approved? && !invalidated? }

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
    cutoff = up_to || Time.current
    project.journal_entries
           .where(review_id: nil)
           .where("created_at <= ?", cutoff)
           .update_all(review_id: id, review_type: "BuildReview")
  end

  def self.backfill_journal_associations!
    BuildReview.where(result: :approved, invalidated: false).find_each do |review|
      review.associate_journal_entries!
      review.save!
    end
  end

  private

  def set_default_tier_override
    self.tier_override ||= project.tier
  end

  def finalize_on_approve
    transaction do
      self.tier_override ||= project.tier
      self.ticket_multiplier ||= BuildReview.default_multiplier_for_tier(effective_tier)
      self.ticket_offset ||= 0

      associate_journal_entries!(up_to: Time.current)

      self.frozen_duration_seconds = journal_entries.sum(:duration_seconds)
      self.frozen_entry_count = journal_entries.count
      self.frozen_tier = effective_tier

      update_columns(
        tier_override: tier_override,
        ticket_multiplier: ticket_multiplier,
        ticket_offset: ticket_offset,
        frozen_duration_seconds: frozen_duration_seconds,
        frozen_entry_count: frozen_entry_count,
        frozen_tier: frozen_tier,
        updated_at: Time.current
      )
    end
  end
end
