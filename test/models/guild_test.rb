# == Schema Information
#
# Table name: guilds
#
#  id               :bigint           not null, primary key
#  city             :string           not null
#  country          :string
#  description      :text
#  latitude         :float
#  longitude        :float
#  name             :string
#  needs_review     :boolean
#  status           :integer          default("pending")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  slack_channel_id :string
#
# Indexes
#
#  index_guilds_on_city_and_country  (city,country) UNIQUE
#
require "test_helper"

class GuildTest < ActiveSupport::TestCase
  test "valid with name" do
    guild = Guild.new(name: "Test Guild")
    assert guild.valid?
  end

  test "invalid without name" do
    guild = Guild.new
    refute guild.valid?
    assert_includes guild.errors[:name], "can't be blank"
  end
end
