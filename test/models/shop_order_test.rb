# == Schema Information
#
# Table name: shop_orders
#
#  id                      :bigint           not null, primary key
#  approved_at             :datetime
#  frozen_address          :jsonb
#  frozen_unit_ticket_cost :integer
#  frozen_unit_usd_cost    :integer
#  fufilled_at             :datetime
#  fufillment_usd_cost     :integer
#  hold_reason             :string
#  internal_notes          :string
#  on_hold_at              :datetime
#  quantity                :integer
#  rejected_at             :datetime
#  rejection_reason        :string
#  state                   :integer          default("pending"), not null
#  tracking_number         :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  approved_by_id          :bigint
#  fufilled_by_id          :bigint
#  on_hold_by_id           :bigint
#  rejected_by_id          :bigint
#  shop_item_id            :bigint           not null
#  user_id                 :bigint           not null
#
# Indexes
#
#  index_shop_orders_on_approved_by_id  (approved_by_id)
#  index_shop_orders_on_fufilled_by_id  (fufilled_by_id)
#  index_shop_orders_on_on_hold_by_id   (on_hold_by_id)
#  index_shop_orders_on_rejected_by_id  (rejected_by_id)
#  index_shop_orders_on_shop_item_id    (shop_item_id)
#  index_shop_orders_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (fufilled_by_id => users.id)
#  fk_rails_...  (on_hold_by_id => users.id)
#  fk_rails_...  (rejected_by_id => users.id)
#  fk_rails_...  (shop_item_id => shop_items.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ShopOrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
