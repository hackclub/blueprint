# == Schema Information
#
# Table name: guild_signups
#
#  id           :bigint           not null, primary key
#  email        :string
#  ideas        :text
#  name         :string
#  project_link :string
#  role         :integer          default(0)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  guild_id     :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_guild_signups_on_guild_id              (guild_id)
#  index_guild_signups_on_user_id               (user_id)
#  index_guild_signups_on_user_id_and_guild_id  (user_id,guild_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (guild_id => guilds.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class GuildSignupTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
