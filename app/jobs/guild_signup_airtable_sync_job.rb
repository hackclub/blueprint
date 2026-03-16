class GuildSignupAirtableSyncJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(signup_id)
    signup = GuildSignup.find_by(id: signup_id)
    return unless signup

    GuildAirtableSync.sync_records!(GuildSignup, [ signup ])
  end
end
