# == Schema Information
#
# Table name: packages
#
#  id              :bigint           not null, primary key
#  address_line_1  :string
#  address_line_2  :string
#  carrier         :string
#  city            :string
#  cost            :decimal(10, 2)
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
require "ostruct"

class Package < ApplicationRecord
  belongs_to :trackable, polymorphic: true

  enum :package_type, {
    hackpad_kit: 0,
    blinky_kit: 1,
    soldering_iron: 2,
    free_stickers: 3,
    other: 4
  }

  PACKAGE_TYPE_LABELS = {
    "hackpad_kit" => "Hackpad Parts Kit",
    "blinky_kit" => "Blinky Parts Kit",
    "soldering_iron" => "Soldering Iron",
    "free_stickers" => "Free Stickers",
    "other" => "Other"
  }.freeze

  PACKAGE_CONTENTS = {
    "hackpad_kit" => [
      { name: "DIY Computer Peripheral Kit (HS 8542.31.0075 - US)", quantity: 1, value: 15.00 }
    ],
    "blinky_kit" => [
      { name: "DIY Electronics Kit (HS 9503.00 - US)", quantity: 1, value: 3.00 }
    ],
    "other" => [
      { name: "Miscellaneous Items", quantity: 1, value: 0.00 }
    ]
  }.freeze

  def package_type_label
    PACKAGE_TYPE_LABELS[package_type] || package_type&.titleize
  end

  def fulfillment_type
    case package_type
    when "hackpad_kit", "blinky_kit", "soldering_iron"
      "Hack Club HQ in Vermont, USA"
    when "free_stickers"
      "Hack Club Warehouse in Vermont, USA"
    else
      nil
    end
  end

  def tracking_link
    case service
    when "Pirate Ship Simple Export Rate"
      "https://a1.asendiausa.com/tracking/?trackingnumber=#{tracking_number}"
    when "Ground Advantage"
      "https://tools.usps.com/go/TrackConfirmAction.action?tLabels=#{tracking_number}"
    else
      nil
    end
  end

  def shipping_cost
    cost
  end

  def owner
    case trackable
    when User then trackable
    when Project, ShopOrder then trackable.user
    end
  end

  def generate_receipt!
    FerrumPdf.render_pdf(
      html: CustomsReceiptTemplate.new(self).call,
      pdf_options: { print_background: true }
    )
  end

  def recipient_address
    [
      recipient_name,
      address_line_1,
      address_line_2.presence,
      "#{city}, #{state} #{postal_code}",
      country
    ].compact.join("\n")
  end

  def contents
    items = PACKAGE_CONTENTS[package_type] || PACKAGE_CONTENTS["other"]
    items.map { |item| OpenStruct.new(item) }
  end

  def total_value
    contents.sum { |item| item.quantity * item.value }
  end
end
