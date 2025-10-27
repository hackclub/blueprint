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
require "test_helper"

class ManualTicketAdjustmentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
