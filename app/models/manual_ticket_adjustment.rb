# == Schema Information
#
# Table name: manual_ticket_adjustments
#
#  id              :bigint           not null, primary key
#  adjustment      :integer
#  internal_reason :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_manual_ticket_adjustments_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ManualTicketAdjustment < ApplicationRecord
  belongs_to :user

  validates :adjustment, presence: true, numericality: { only_integer: true }
  validates :internal_reason, presence: true
end
