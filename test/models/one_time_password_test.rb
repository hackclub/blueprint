# == Schema Information
#
# Table name: one_time_passwords
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  expires_at :datetime
#  request_ip :string
#  secret     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_one_time_passwords_on_email  (email)
#
require "test_helper"

class OneTimePasswordTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
