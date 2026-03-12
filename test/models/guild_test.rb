# == Schema Information
#
# Table name: guilds
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
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
