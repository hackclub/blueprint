# == Schema Information
#
# Table name: privacy_token_uses
#
#  id      :bigint           not null, primary key
#  jti     :string           not null
#  used_at :datetime         not null
#
# Indexes
#
#  index_privacy_token_uses_on_jti      (jti) UNIQUE
#  index_privacy_token_uses_on_used_at  (used_at)
#
class PrivacyTokenUse < ApplicationRecord
  RETENTION = 1.day

  def self.first_use?(jti)
    insert({ jti: jti }, unique_by: :jti, returning: :id).rows.any?
  end

  def self.prune!
    where(used_at: ...RETENTION.ago).delete_all
  end
end
