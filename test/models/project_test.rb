# == Schema Information
#
# Table name: projects
#
#  id                     :bigint           not null, primary key
#  approved_funding_cents :integer
#  approved_tier          :integer
#  approx_hour            :decimal(3, 1)
#  demo_link              :string
#  description            :text
#  funding_needed_cents   :integer          default(0), not null
#  hackatime_project_keys :string           default([]), is an Array
#  is_deleted             :boolean          default(FALSE)
#  journal_entries_count  :integer          default(0), not null
#  needs_funding          :boolean          default(TRUE)
#  needs_soldering_iron   :boolean          default(FALSE), not null
#  print_legion           :boolean          default(FALSE), not null
#  project_type           :string
#  readme_link            :string
#  repo_link              :string
#  review_status          :string
#  reviewer_note          :text
#  skip_gh_sync           :boolean          default(FALSE)
#  tier                   :integer
#  title                  :string
#  unlisted               :boolean          default(FALSE), not null
#  views_count            :integer          default(0), not null
#  viral                  :boolean          default(FALSE), not null
#  ysws                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_projects_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
