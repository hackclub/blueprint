# == Schema Information
#
# Table name: hcb_transactions
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer
#  first_seen_at  :datetime         not null
#  hcb_created_at :datetime
#  last_seen_at   :datetime         not null
#  last_synced_at :datetime
#  memo           :text
#  receipt_count  :integer
#  source_url     :string
#  status         :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hcb_grant_id   :bigint           not null
#  org_id         :string           not null
#  transaction_id :string           not null
#
# Indexes
#
#  index_hcb_transactions_on_hcb_grant_id               (hcb_grant_id)
#  index_hcb_transactions_on_last_seen_at               (last_seen_at)
#  index_hcb_transactions_on_org_id_and_transaction_id  (org_id,transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (hcb_grant_id => hcb_grants.id)
#
class HcbTransaction < ApplicationRecord
  belongs_to :hcb_grant

  validates :org_id, presence: true
  validates :transaction_id, presence: true
  validates :first_seen_at, presence: true
  validates :last_seen_at, presence: true
end
