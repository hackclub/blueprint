# == Schema Information
#
# Table name: guild_airtable_syncs
#
#  id                     :bigint           not null, primary key
#  last_synced_at         :datetime
#  record_identifier      :string
#  synced_attributes_hash :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  airtable_id            :string
#
# Indexes
#
#  index_guild_airtable_syncs_on_record_identifier  (record_identifier) UNIQUE
#
require "test_helper"

class GuildAirtableSyncTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
