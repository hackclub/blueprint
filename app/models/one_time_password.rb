# == Schema Information
#
# Table name: one_time_passwords
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  expires_at :datetime
#  secret     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_one_time_passwords_on_email  (email)
#
class OneTimePassword < ApplicationRecord
  before_validation :generate, on: :create
  before_validation :normalize_email

  validates :secret, :expires_at, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :with_email, ->(email) { where("LOWER(email) = ?", email.to_s.strip.downcase) }

  def expired?
    Time.current > expires_at
  end

  def send!
    AuthMailer.with(email: email, otp: secret).otp_email.deliver_later(queue: :realtime)
    true
  end

  def self.valid?(secret, email)
    otps = with_email(email).where(secret: secret)
    valid = otps.any? { |otp| !otp.expired? }
    otps.each(&:destroy)
    valid
  end

  private

  def generate
    self.secret ||= SecureRandom.random_number(1000000).to_s.rjust(6, "0")
    self.expires_at ||= 15.minutes.from_now
  end

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
