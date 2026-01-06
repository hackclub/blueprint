# == Schema Information
#
# Table name: shop_items
#
#  id             :bigint           not null, primary key
#  desc           :string
#  enabled        :boolean
#  name           :string
#  one_per_person :boolean
#  ticket_cost    :integer
#  total_stock    :integer
#  type           :string
#  usd_cost       :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class ShopItem < ApplicationRecord
  has_paper_trail

  has_one_attached :image

  validates :image, content_type: [ "image/png", "image/jpeg", "image/webp", "image/gif" ],
                    size: { less_than: 5.megabytes }

  def fulfill!(*args)
    # does nothing by default
  end

  def self.fulfill_immediately?
    false
  end
end
