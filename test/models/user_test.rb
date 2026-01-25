# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  admin                       :boolean          default(FALSE), not null
#  avatar                      :string
#  ban_type                    :integer
#  birthday                    :date
#  email                       :string           not null
#  free_stickers_claimed       :boolean          default(FALSE), not null
#  fulfiller                   :boolean          default(FALSE), not null
#  github_username             :string
#  identity_vault_access_token :string
#  idv_country                 :string
#  internal_notes              :text
#  is_banned                   :boolean          default(FALSE), not null
#  is_mcg                      :boolean          default(FALSE), not null
#  is_pro                      :boolean          default(FALSE)
#  last_active                 :datetime
#  last_impersonated_at        :datetime
#  last_impersonation_ended_at :datetime
#  reviewer                    :boolean          default(FALSE), not null
#  shopkeeper                  :boolean          default(FALSE), not null
#  timezone_raw                :string
#  username                    :string
#  ysws_verified               :boolean
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  github_installation_id      :bigint
#  identity_vault_id           :string
#  referrer_id                 :bigint
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_referrer_id  (referrer_id)
#
# Foreign Keys
#
#  fk_rails_...  (referrer_id => users.id)
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
