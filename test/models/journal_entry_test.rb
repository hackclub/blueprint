# == Schema Information
#
# Table name: journal_entries
#
#  id               :bigint           not null, primary key
#  content          :text
#  duration_seconds :integer          default(0), not null
#  review_type      :string
#  summary          :string
#  views            :bigint           default([]), not null, is an Array
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  project_id       :bigint           not null
#  review_id        :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_journal_entries_on_project_id                 (project_id)
#  index_journal_entries_on_review                     (review_type,review_id)
#  index_journal_entries_on_review_type_and_review_id  (review_type,review_id)
#  index_journal_entries_on_user_id                    (user_id)
#  index_journal_entries_unreviewed_by_project         (project_id,created_at) WHERE (review_id IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class JournalEntryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
