# == Schema Information
#
# Table name: privileged_session_expiries
#
#  id         :bigint           not null, primary key
#  expires_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_privileged_session_expiries_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class PrivilegedSessionExpiry < ApplicationRecord
  has_paper_trail

  belongs_to :user

  SESSION_DURATION = 7.days

  def self.set_expiry_for(user)
    record = find_or_initialize_by(user: user)
    record.update!(expires_at: SESSION_DURATION.from_now)
  end

  def self.invalidate_all!
    update_all(expires_at: Time.current)
  end

  def expired?
    Time.current > expires_at
  end
end
