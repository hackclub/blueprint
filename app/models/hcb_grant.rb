# == Schema Information
#
# Table name: hcb_grants
#
#  id                   :bigint           not null, primary key
#  balance_cents        :integer
#  first_seen_at        :datetime         not null
#  for_reason           :text
#  initial_amount_cents :integer
#  issued_at            :datetime
#  last_seen_at         :datetime         not null
#  last_sync_error      :text
#  last_synced_at       :datetime
#  soft_deleted_at      :datetime
#  source_url           :string
#  status               :string
#  sync_failures_count  :integer          default(0), not null
#  to_user_avatar       :text
#  to_user_name         :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  grant_id             :string           not null
#  org_id               :string           not null
#
# Indexes
#
#  index_hcb_grants_on_last_seen_at         (last_seen_at)
#  index_hcb_grants_on_org_id_and_grant_id  (org_id,grant_id) UNIQUE
#  index_hcb_grants_on_soft_deleted_at      (soft_deleted_at)
#
class HcbGrant < ApplicationRecord
  has_many :hcb_transactions, dependent: :destroy

  validates :org_id, presence: true
  validates :grant_id, presence: true
  validates :first_seen_at, presence: true
  validates :last_seen_at, presence: true

  scope :active, -> { where(soft_deleted_at: nil) }
  scope :soft_deleted, -> { where.not(soft_deleted_at: nil) }
end
