# == Schema Information
#
# Table name: packages
#
#  id              :bigint           not null, primary key
#  address_line_1  :string
#  address_line_2  :string
#  carrier         :string
#  city            :string
#  cost            :decimal(, )
#  country         :string
#  package_type    :integer
#  postal_code     :string
#  recipient_email :string
#  recipient_name  :string
#  sent_at         :datetime
#  service         :string
#  state           :string
#  trackable_type  :string           not null
#  tracking_number :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  trackable_id    :bigint           not null
#
# Indexes
#
#  index_packages_on_trackable  (trackable_type,trackable_id)
#
class Package < ApplicationRecord
  belongs_to :trackable, polymorphic: true

  enum :package_type, {
    hackpad_kit: 0,
    blinky_kit: 1,
    soldering_iron: 2,
    free_stickers: 3,
    other: 4
  }
end
